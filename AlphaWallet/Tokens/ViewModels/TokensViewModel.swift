// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import Combine
import AlphaWalletAttestation
import AlphaWalletCore
import AlphaWalletFoundation

struct TokensViewModelInput {
    let appear: AnyPublisher<Void, Never>
    let pullToRefresh: AnyPublisher<Void, Never>
    let selection: AnyPublisher<TokensViewModel.SelectionSource, Never>
    let keyboard: AnyPublisher<KeyboardChecker.KeyboardState, Never>
}

struct TokensViewModelOutput {
    let viewState: AnyPublisher<TokensViewModel.ViewState, Never>
    let selection: AnyPublisher<TokenOrAttestation, Never>
    let pullToRefreshState: AnyPublisher<TokensViewModel.RefreshControlState, Never>
    let deletion: AnyPublisher<[IndexPath], Never>
    let applyTableInset: AnyPublisher<TokensViewModel.KeyboardInset, Never>
}

//Must be a class, and not a struct, otherwise changing `filter` will silently create a copy of TokensViewModel when user taps to change the filter in the UI and break filtering
// swiftlint:disable type_body_length
final class TokensViewModel {
    private let tokensService: TokensService
    private let tokensPipeline: TokensProcessingPipeline
    private let walletConnectProvider: WalletConnectProvider
    private let walletBalanceService: WalletBalanceService
    //Must be computed because localization can be overridden by user dynamically
    static var segmentedControlTitles: [String] { WalletFilter.orderedTabs.map { $0.title } }
    private var cancellable = Set<AnyCancellable>()
    private let tokensFilter: TokensFilter
    private (set) var isSearchActive: Bool = false

    //These can be updated anytime; only used to compute the next UI state and must not be read by others
    private var tokens: [TokenViewModel] = []
    private var walletConnectSessions: Int = 0

    //This is controlled by the UI and other view state and the other parts of the UI might or might not have handled this yet
    private (set) var filterInUserInterface: WalletFilter = .all

    //This is the committed state of the UI
    var viewState: ViewState!

    private let attestationsStore: AttestationsStore
    private lazy var _attestations: [Attestation] = attestationsStore.attestations
    private var attestations: [Attestation] {
        _attestations.filter { serversProvider.enabledServers.contains($0.server) }
    }

    private lazy var walletNameFetcher = GetWalletName(domainResolutionService: domainResolutionService)
    private let domainResolutionService: DomainNameResolutionServiceType
    private let blockiesGenerator: BlockiesGenerator
    private let sectionViewModelsSubject = CurrentValueSubject<Void, Never>(())
    private let sectionViewModelsImmediateSubject = CurrentValueSubject<Void, Never>(())
    private let deletionSubject = PassthroughSubject<[IndexPath], Never>()
    private let wallet: Wallet
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokenImageFetcher: TokenImageFetcher
    private let serversProvider: ServersProvidable

    let config: Config
    let largeTitleDisplayMode: UINavigationItem.LargeTitleDisplayMode = .never
    var filterViewModel: (cells: [ScrollableSegmentedControlCell], configuration: ScrollableSegmentedControlConfiguration) {
        let cellConfiguration = Style.ScrollableSegmentedControlCell.configuration
        let controlConfiguration = Style.ScrollableSegmentedControl.configuration
        let cells = TokensViewModel.segmentedControlTitles.map { title in
            ScrollableSegmentedControlCell(frame: .zero, title: title, configuration: cellConfiguration)
        }
        return (cells: cells, configuration: controlConfiguration)
    }

    var emptyTokensTitle: String {
        switch filterInUserInterface {
        case .assets:
            return R.string.localizable.emptyTableViewWalletTitle(R.string.localizable.aWalletContentsFilterAssetsOnlyTitle())
        case .collectiblesOnly:
            return R.string.localizable.emptyTableViewWalletTitle(R.string.localizable.aWalletContentsFilterCollectiblesOnlyTitle())
        case .defi:
            return R.string.localizable.emptyTableViewWalletTitle(R.string.localizable.aWalletContentsFilterDefiTitle())
        case .governance:
            return R.string.localizable.emptyTableViewWalletTitle(R.string.localizable.aWalletContentsFilterGovernanceTitle())
        case .keyword:
            return R.string.localizable.emptyTableViewSearchTitle()
        case .all:
            return R.string.localizable.emptyTableViewWalletTitle(R.string.localizable.emptyTableViewAllTitle())
        case .attestations:
            return R.string.localizable.attestationsAttestations()
        case .filter:
            return R.string.localizable.emptyTableViewSearchTitle()
        }
    }

    var headerBackgroundColor: UIColor {
        return Configuration.Color.Semantic.defaultViewBackground
    }

    var buyCryptoTitle: String {
        return R.string.localizable.buyCryptoTitle()
    }

    var backgroundColor: UIColor {
        return Configuration.Color.Semantic.searchBarBackground
    }

    var buyButtonFooterBarBackgroundColor: UIColor {
        return .clear
    }

    var shouldShowBackupPromptViewHolder: Bool {
            //TODO show the prompt in both ASSETS and COLLECTIBLES tab too
        switch filterInUserInterface {
        case .all, .keyword:
            return true
        case .assets, .collectiblesOnly, .filter, .defi, .governance, .attestations:
            return false
        }
    }

    init(wallet: Wallet,
         tokensPipeline: TokensProcessingPipeline,
         tokensFilter: TokensFilter,
         walletConnectProvider: WalletConnectProvider,
         walletBalanceService: WalletBalanceService,
         config: Config,
         domainResolutionService: DomainNameResolutionServiceType,
         blockiesGenerator: BlockiesGenerator,
         assetDefinitionStore: AssetDefinitionStore,
         tokenImageFetcher: TokenImageFetcher,
         serversProvider: ServersProvidable,
         tokensService: TokensService,
         attestationsStore: AttestationsStore) {
        self.tokensService = tokensService
        self.attestationsStore = attestationsStore
        self.tokenImageFetcher = tokenImageFetcher
        self.wallet = wallet
        self.tokensPipeline = tokensPipeline
        self.tokensFilter = tokensFilter
        self.walletConnectProvider = walletConnectProvider
        self.walletBalanceService = walletBalanceService
        self.config = config
        self.domainResolutionService = domainResolutionService
        self.blockiesGenerator = blockiesGenerator
        self.assetDefinitionStore = assetDefinitionStore
        self.serversProvider = serversProvider
    }

    func transform(input: TokensViewModelInput) -> TokensViewModelOutput {
        cancellable.cancellAll()

        let pullToRefreshState = pullToRefreshState(input: input.pullToRefresh)

        Publishers.Merge(input.appear, input.pullToRefresh)
            .receive(on: RunLoop.main)
            .sink { [tokensService] _ in tokensService.refresh() }
            .store(in: &cancellable)

        walletConnectProvider.sessionsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] sessions in
                self?.walletConnectSessions = sessions.count
                self?.reloadData(immediately: true)
            }.store(in: &cancellable)

        tokensPipeline.tokenViewModels
            .prepend([])
            .sink { [weak self] tokens in
                self?.tokens = tokens
                self?.reloadData()
            }.store(in: &cancellable)

        let walletSummary = walletSummary()
        let title = title(input: input.appear)
        let blockieImage = blockieImage(input: input.appear)
        let selection = selection(trigger: input.selection)

        let titleWithListOfBadTokenScriptFiles = Publishers.CombineLatest(title, assetDefinitionStore.listOfBadTokenScriptFiles)
        let firstNonZeroTokens = sectionViewModelsSubject.filter {
            let (sectionsViewModels, _, _) = functional.generateDisplayState(tokens: self.tokens, attestations: self.attestations, tokensFilter: self.tokensFilter, filterInUserInterface: self.filterInUserInterface, walletConnectSessions: self.walletConnectSessions, isSearchActive: self.isSearchActive, tokenImageFetcher: self.tokenImageFetcher, assetDefinitionStore: self.assetDefinitionStore)
            //We could simplify the above code to just generate and the list of tokens for `.tokens` and perform less work, but it's not called often, so lets keep it simple
            if let s = sectionsViewModels.first(where: { $0.section == .tokens }) {
                return !s.views.isEmpty
            } else {
                return false
            }
            //Completely empirical because prefix(1) wasn't fast enough at launch
        }.prefix(2)
        //Throttle heavily so we don't freeze the UI for a few seconds after first launch and tokens are displayed
        let throttledTokensSubject = sectionViewModelsSubject.throttle(for: .seconds(10), scheduler: DispatchQueue.main, latest: true)
        let compositeSectionViewModelsSubject = Publishers.Merge3(firstNonZeroTokens, throttledTokensSubject, sectionViewModelsImmediateSubject)

        //TODO might have cyclic references
        let viewState = Publishers.CombineLatest4(compositeSectionViewModelsSubject, walletSummary, blockieImage, titleWithListOfBadTokenScriptFiles)
            //Prevent crash, keeping updates serialized so receiving end can update with atomic state
            .receive(on: RunLoop.main)
            .map { _, summary, blockiesImage, data -> TokensViewModel.ViewState in
                let (sectionsViewModels, filteredTokens, sections) = functional.generateDisplayState(tokens: self.tokens, attestations: self.attestations, tokensFilter: self.tokensFilter, filterInUserInterface: self.filterInUserInterface, walletConnectSessions: self.walletConnectSessions, isSearchActive: self.isSearchActive, tokenImageFetcher: self.tokenImageFetcher, assetDefinitionStore: self.assetDefinitionStore)
                let isConsoleButtonHidden = data.1.isEmpty
                return TokensViewModel.ViewState(
                    title: data.0,
                    summary: summary,
                    blockiesImage: blockiesImage,
                    isConsoleButtonHidden: isConsoleButtonHidden,
                    isFooterHidden: self.isFooterHidden,
                    viewModels: sectionsViewModels,
                    filteredRows: filteredTokens,
                    sections: sections,
                    filter: self.filterInUserInterface,
                    walletConnectSessions: self.walletConnectSessions)
            }.removeDuplicates()
            .eraseToAnyPublisher()

        let applyTableInset = applyTableInset(keyboard: input.keyboard)

        attestationsStore.$attestations
            .sink {
                self._attestations = $0
                self.reloadData(immediately: true)
            }
            .store(in: &cancellable)

        reloadData()

        return .init(
            viewState: viewState,
            selection: selection,
            pullToRefreshState: pullToRefreshState,
            deletion: deletionSubject.eraseToAnyPublisher(),
            applyTableInset: applyTableInset)
    }

    private func walletSummary() -> AnyPublisher<WalletSummary, Never> {
        walletBalanceService
            .walletBalance(for: wallet)
            .map { value in WalletSummary(balances: [value]) }
            .prepend(WalletSummary(balances: []))
            .eraseToAnyPublisher()
    }

    private func blockieImage(input appear: AnyPublisher<Void, Never>) -> AnyPublisher<BlockiesImage, Never> {
        return appear.flatMap { [blockiesGenerator, wallet] _ in
            let result: CurrentValueSubject<BlockiesImage, Never> = CurrentValueSubject(BlockiesImage.defaulBlockieImage)
            Task {
                result.value = await blockiesGenerator.getBlockieOrEnsAvatarImage(address: wallet.address, fallbackImage: BlockiesImage.defaulBlockieImage)
            }
            return result
        }.eraseToAnyPublisher()
    }

    private func title(input appear: AnyPublisher<Void, Never>) -> AnyPublisher<String, Never> {
        return appear.flatMap { [walletNameFetcher, wallet] _ -> AnyPublisher<String, Never> in
            walletNameFetcher.assignedNameOrEns(for: wallet.address)
                .map { $0 ?? wallet.address.truncateMiddle }
                .eraseToAnyPublisher()
        }.prepend(wallet.address.truncateMiddle)
        .eraseToAnyPublisher()
    }

    private func pullToRefreshState(input pullToRefresh: AnyPublisher<Void, Never>) -> AnyPublisher<RefreshControlState, Never> {
        let beginLoading = pullToRefresh.map { _ in PullToRefreshState.beginLoading }
        let loadingHasEnded = beginLoading.delay(for: .seconds(2), scheduler: RunLoop.main)
            .map { _ in PullToRefreshState.endLoading }

        return Just<PullToRefreshState>(PullToRefreshState.idle)
            .merge(with: beginLoading, loadingHasEnded)
            .compactMap { state -> TokensViewModel.RefreshControlState? in
                switch state {
                case .idle: return nil
                case .endLoading: return .endLoading
                case .beginLoading: return .beginLoading
                }
            }.eraseToAnyPublisher()
    }

    private func applyTableInset(keyboard: AnyPublisher<KeyboardChecker.KeyboardState, Never>) -> AnyPublisher<KeyboardInset, Never> {
        keyboard
            .map { $0.isVisible }
            .prepend(false)
            .map { [unowned self] in self.isFooterHidden ? KeyboardInset.none : KeyboardInset.some($0) }
            .eraseToAnyPublisher()
    }

    private func selection(trigger: AnyPublisher<TokensViewModel.SelectionSource, Never>) -> AnyPublisher<TokenOrAttestation, Never> {
        trigger.flatMap { [unowned self, tokensService] source in
            asFuture { () -> TokenOrAttestation? in
                switch source {
                case .gridItem(let indexPath, let isLeftCardSelected):
                    switch self.viewState.sections[indexPath.section] {
                    case .collectiblePairs:
                        let pair = functional.collectiblePairs(filteredTokens: self.viewState.filteredRows)[indexPath.row]
                        guard let viewModel: TokenViewModel = isLeftCardSelected ? pair.left : pair.right else { return nil }

                        return await tokensService.token(for: viewModel.contractAddress, server: viewModel.server).flatMap { TokenOrAttestation.token($0) }
                    case .tokens, .activeWalletSession, .filters, .search, .walletSummary:
                        return nil
                    }
                case .cell(let indexPath):
                    let tokenOrServer = self.tokenOrServer(at: indexPath)
                    switch (self.viewState.sections[indexPath.section], tokenOrServer) {
                    case (.tokens, .token(let viewModel)):
                        return .token(await tokensService.token(for: viewModel.contractAddress, server: viewModel.server)!)
                    case (.tokens, .attestation(let attestation)):
                        return .attestation(attestation)
                    case (_, _):
                        return nil
                    }
                }
            }
        }.compactMap { $0 }.eraseToAnyPublisher()
    }

    private var isFooterHidden: Bool {
        if Features.current.isAvailable(.buyCryptoEnabled) {
            return !serversProvider.enabledServers.contains(.main)
        } else {
            return true
        }
    }

    func set(isSearchActive: Bool) {
        self.isSearchActive = isSearchActive
        reloadData(immediately: true)
    }

    func set(filterInUserInterface: WalletFilter) {
        self.filterInUserInterface = filterInUserInterface
        reloadData(immediately: true)
    }

    private func tokenOrServer(at indexPath: IndexPath) -> TokenOrRpcServer {
        return viewState.filteredRows[indexPath.row]
    }

    func trailingSwipeActionsConfiguration(for indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        func trailingSwipeActionsConfiguration(forRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
            let item = tokenOrServer(at: indexPath)
            guard item.canDelete else { return nil }
            switch item {
            case .rpcServer:
                return nil
            case .token(let token):
                let title = R.string.localizable.walletsHideTokenTitle()
                let hideAction = UIContextualAction(style: .destructive, title: title) { [weak self] (_, _, completion) in
                    guard let strongSelf = self else { return }

                    let deletedIndexPathArray = strongSelf.indexPathArrayForDeletingAt(indexPath: indexPath)
                    strongSelf.markTokenHidden(token: token)

                    guard !deletedIndexPathArray.isEmpty else { return }
                    strongSelf.deletionSubject.send(deletedIndexPathArray)

                    completion(true)
                }

                hideAction.backgroundColor = Configuration.Color.Semantic.dangerBackground
                hideAction.image = R.image.hideToken()
                let configuration = UISwipeActionsConfiguration(actions: [hideAction])
                configuration.performsFirstActionWithFullSwipe = true

                return configuration
            case .attestation(let attestation):
                let title = R.string.localizable.delete()
                let hideAction = UIContextualAction(style: .destructive, title: title) { [weak self] (_, _, completion) in
                    guard let strongSelf = self else { return }

                    let deletedIndexPathArray = strongSelf.indexPathArrayForDeletingAt(indexPath: indexPath)
                    strongSelf.removeAttestation(attestation)

                    guard !deletedIndexPathArray.isEmpty else { return }
                    strongSelf.deletionSubject.send(deletedIndexPathArray)

                    completion(true)
                }

                hideAction.backgroundColor = Configuration.Color.Semantic.dangerBackground
                hideAction.image = R.image.hideToken()
                let configuration = UISwipeActionsConfiguration(actions: [hideAction])
                configuration.performsFirstActionWithFullSwipe = true

                return configuration
            }
        }

        switch viewState.sections[indexPath.section] {
        case .collectiblePairs, .search, .walletSummary, .filters, .activeWalletSession:
            return nil
        case .tokens:
            return trailingSwipeActionsConfiguration(forRowAt: indexPath)
        }
    }

    func cellHeight(for indexPath: IndexPath) -> CGFloat {
        switch viewState.sections[indexPath.section] {
        case .tokens:
            switch tokenOrServer(at: indexPath) {
            case .rpcServer:
                return DataEntry.Metric.Tokens.headerHeight
            case .token:
                return DataEntry.Metric.Tokens.cellHeight
            case .attestation:
                return DataEntry.Metric.Tokens.cellHeight
            }
        case .search, .walletSummary, .filters, .activeWalletSession:
            return DataEntry.Metric.Tokens.cellHeight
        case .collectiblePairs:
            return DataEntry.Metric.Tokens.collectiblePairsHeight
        }
    }

    private func markTokenHidden(token: TokenViewModel) {
        tokensService.mark(token: token, isHidden: true)
        if let index = tokens.firstIndex(where: { $0 == token }) {
            tokens.remove(at: index)
        }
    }

    private func removeAttestation(_ attestation: Attestation) {
        attestationsStore.removeAttestation(attestation, forWallet: wallet.address)
    }

    func convertSegmentedControlSelectionToFilter(_ selection: ControlSelection) -> WalletFilter? {
        switch selection {
        case .selected(let index):
            return WalletFilter.filter(fromIndex: index)
        case .unselected:
            return nil
        }
    }

    private func indexPathArrayForDeletingAt(indexPath current: IndexPath) -> [IndexPath] {
        let canRemoveCurrentItem: Bool = tokenOrServer(at: current).isRemovable
        let canRemovePreviousItem: Bool = current.row > 0 ? tokenOrServer(at: current.previous).isRemovable : false
        let canRemoveNextItem: Bool = {
            guard (current.row + 1) < viewState.filteredRows.count else { return false }
            return tokenOrServer(at: current.next).isRemovable
        }()
        switch (canRemovePreviousItem, canRemoveCurrentItem, canRemoveNextItem) {
            // Truth table for deletion
            // previous, current, next
            // 0, 0, 0
            // return []
            // 0, 0, 1
            // return []
            // 0, 1, 0
            // return [current.previous, current]
            // 0, 1, 1
            // return [current]
            // 1, 0, 0
            // return []
            // 1, 0, 1
            // return []
            // 1, 1, 0
            // return [current]
            // 1, 1, 1
            // return [current]
        case (_, false, _):
            return []
        case (false, true, false):
            return [current.previous, current]
        default:
            return [current]
        }
    }

    private func reloadData(immediately: Bool = false) {
        if immediately {
            sectionViewModelsImmediateSubject.send()
        } else {
            sectionViewModelsSubject.send()
        }
    }
}
// swiftlint:enable type_body_length

extension TokensViewModel {
    enum HideTokenResult {
        case success(indexPaths: [IndexPath])
        case failure
    }

    enum TokenOrRpcServer: Hashable {
        case token(TokenViewModel)
        case rpcServer(RPCServer)
        case attestation(Attestation)

        var debugName: String {
            switch self {
            case .rpcServer:
                return "rpcServer"
            case .token:
                return "token"
            case .attestation:
                return "attestation"
            }
        }

        var token: TokenViewModel? {
            switch self {
            case .rpcServer:
                return nil
            case .token(let token):
                return token
            case .attestation:
                return nil
            }
        }

        var canDelete: Bool {
            switch self {
            case .rpcServer:
                return false
            case .token(let token):
                if token.contractAddress == Constants.nativeCryptoAddressInDatabase {
                    return false
                }
                return true
            case .attestation:
                return true
            }
        }

        var isRemovable: Bool {
            switch self {
            case .rpcServer:
                return false
            case .token:
                return true
            case .attestation:
                return true
            }
        }
    }

    struct CollectiblePairs: Hashable {
        let left: TokenViewModel
        let right: TokenViewModel?
    }

    enum Section: Int, Hashable {
        case walletSummary
        case filters
        case search
        case tokens
        case collectiblePairs
        case activeWalletSession
    }

    enum ViewModelType {
        case nftCollection(OpenSeaNonFungibleTokenPairTableCellViewModel)
        case nonFungible(NonFungibleTokenViewCellViewModel)
        case fungibleToken(FungibleTokenViewCellViewModel)
        case nativeCryptocurrency(EthTokenViewCellViewModel)
        case rpcServer(TokenListServerTableViewCellViewModel)
        case attestation(AttestationViewCellViewModel)
        case undefined

        var debugName: String {
            switch self {
            case .nftCollection:
                return "nftCollection"
            case .nonFungible:
                return "nonFungible"
            case .fungibleToken:
                return "fungibleToken"
            case .nativeCryptocurrency:
                return "nativeCryptocurrency"
            case .rpcServer:
                return "rpcServer"
            case .attestation:
                return "attestation"
            case .undefined:
                return "undefined"
            }
        }
    }

    struct SectionViewModel {
        let section: Section
        let views: [TokensViewModel.ViewModelType]
    }

    enum TokensLayoutType {
        case list
        case grid
    }

    enum SelectionSource {
        case gridItem(indexPath: IndexPath, isLeftCardSelected: Bool)
        case cell(indexPath: IndexPath)
    }

    enum PullToRefreshState {
        case idle
        case beginLoading
        case endLoading
    }

    enum RefreshControlState {
        case beginLoading
        case endLoading
    }

    enum KeyboardInset {
        case some(Bool)
        case none
    }

    struct ViewState {
        let title: String
        let summary: WalletSummary
        let blockiesImage: BlockiesImage
        let isConsoleButtonHidden: Bool
        let isFooterHidden: Bool
        let viewModels: [TokensViewModel.SectionViewModel]
        let filteredRows: [TokenOrRpcServer]
        let sections: [Section]
        let filter: WalletFilter
        let walletConnectSessions: Int

        func heightForHeaderInSection(for section: Int) -> CGFloat {
            switch sections[section] {
            case .walletSummary:
                return 80
            case .filters:
                return DataEntry.Metric.Tokens.Filter.height
            case .activeWalletSession:
                return 80
            case .search:
                return DataEntry.Metric.AddHideToken.Header.height
            case .tokens, .collectiblePairs:
                return 0.01
            }
        }

        func numberOfItems(for section: Int) -> Int {
            return TokensViewModel.functional.numberOfItems(for: section, sections: sections, filteredTokens: filteredRows, collectiblePairs: functional.collectiblePairs(filteredTokens: filteredRows), filter: filter)
        }
    }
}

extension TokensViewModel.ViewState: Hashable { }
extension TokensViewModel.SectionViewModel: Hashable { }
extension TokensViewModel.ViewModelType: Hashable { }

extension WalletFilter {
    static var orderedTabs: [WalletFilter] {
        return [
            .all,
            .attestations,
            .assets,
            .collectiblesOnly,
            .defi,
            .governance,
        ]
    }

    var selectionIndex: UInt? {
        //This is safe only because index can't possibly be negative
        return WalletFilter.orderedTabs.firstIndex { $0 == self }.flatMap { UInt($0) }
    }
}

fileprivate extension WalletFilter {
    static func filter(fromIndex index: UInt) -> WalletFilter? {
        return WalletFilter.orderedTabs.first { $0.selectionIndex == index }
    }

    var title: String {
        switch self {
        case .all:
            return R.string.localizable.aWalletContentsFilterAllTitle()
        case .defi:
            return R.string.localizable.aWalletContentsFilterDefiTitle()
        case .governance:
            return R.string.localizable.aWalletContentsFilterGovernanceTitle()
        case .assets:
            return R.string.localizable.aWalletContentsFilterAssetsOnlyTitle()
        case .collectiblesOnly:
            return R.string.localizable.aWalletContentsFilterCollectiblesOnlyTitle()
        case .keyword, .filter:
            return ""
        case .attestations:
            return R.string.localizable.attestationsAttestations()
        }
    }
}

extension TokensViewModel {
    enum functional {}
}

fileprivate extension TokensViewModel.functional {
    static func groupTokensByServers(tokens: [TokenViewModel], attestations: [Attestation]) -> [TokensViewModel.TokenOrRpcServer] {
        var servers: [RPCServer] = []
        var results: [TokensViewModel.TokenOrRpcServer] = []

        for each in tokens {
            guard !servers.contains(each.server) else { continue }
            servers.append(each.server)
        }
        for each in attestations {
            guard !servers.contains(each.server) else { continue }
            servers.append(each.server)
        }

        for each in servers {
            let tokens = tokens.filter { $0.server == each }.map { TokensViewModel.TokenOrRpcServer.token($0) }
            let attestations = attestations.filter { $0.server == each }.map { TokensViewModel.TokenOrRpcServer.attestation($0) }
            guard !tokens.isEmpty || !attestations.isEmpty else { continue }

            results.append(.rpcServer(each))
            results.append(contentsOf: tokens)
            results.append(contentsOf: attestations)
        }

        return results
    }

    static func filteredAndSortedTokens(tokens: [TokenViewModel], attestations: [Attestation], tokensFilter: TokensFilter, filter: WalletFilter) -> [TokensViewModel.TokenOrRpcServer] {
        //TODO include filtering attestations too
        let displayedTokens = tokensFilter.filterTokens(tokens: tokens, filter: filter)
        let tokens = tokensFilter.sortDisplayedTokens(tokens: displayedTokens)
        switch filter {
        case .all:
            return TokensViewModel.functional.groupTokensByServers(tokens: tokens, attestations: attestations)
        case .filter, .defi, .governance, .assets, .keyword:
            return TokensViewModel.functional.groupTokensByServers(tokens: tokens, attestations: [])
        case .attestations:
            return TokensViewModel.functional.groupTokensByServers(tokens: [], attestations: attestations)
        case .collectiblesOnly:
            return tokens.map { .token($0) }
        }
    }

    static func refreshSections(walletConnectSessions count: Int, isSearchActive: Bool, filter: WalletFilter) -> [TokensViewModel.Section] {
        let tokenSection: TokensViewModel.Section = {
            switch filter {
            case .all, .defi, .governance, .keyword, .assets, .filter, .attestations:
                return .tokens
            case .collectiblesOnly:
                return .collectiblePairs
            }
        }()

        if isSearchActive {
            return [tokenSection]
        } else {
            let initialSections: [TokensViewModel.Section]

            if count == .zero {
                initialSections = [.walletSummary, .filters, .search]
            } else {
                initialSections = [.walletSummary, .filters, .search, .activeWalletSession]
            }
            return initialSections + [tokenSection]
        }
    }

    static func buildSectionViewModels(sections: [TokensViewModel.Section], filteredTokens: [TokensViewModel.TokenOrRpcServer], collectiblePairs: [TokensViewModel.CollectiblePairs], filter: WalletFilter, tokenImageFetcher: TokenImageFetcher, assetDefinitionStore: AssetDefinitionStore) -> [TokensViewModel.SectionViewModel] {
        return sections.enumerated().map { (sectionIndex, section) -> TokensViewModel.SectionViewModel in
            let numberOfItems = numberOfItems(for: sectionIndex, sections: sections, filteredTokens: filteredTokens, collectiblePairs: collectiblePairs, filter: filter)
            guard numberOfItems > 0 else {
                return TokensViewModel.SectionViewModel(section: section, views: [])
            }

            let viewModels = (0 ..< numberOfItems).map { row -> TokensViewModel.ViewModelType in
                let indexPath = IndexPath(row: row, section: sectionIndex)
                return TokensViewModel.functional.viewModel(for: indexPath, sections: sections, filteredTokens: filteredTokens, collectiblePairs: collectiblePairs, tokenImageFetcher: tokenImageFetcher, assetDefinitionStore: assetDefinitionStore)
            }

            return TokensViewModel.SectionViewModel(section: section, views: viewModels)
        }
    }

    static func numberOfItems(for section: Int, sections: [TokensViewModel.Section], filteredTokens: [TokensViewModel.TokenOrRpcServer], collectiblePairs: [TokensViewModel.CollectiblePairs], filter: WalletFilter) -> Int {
        switch sections[section] {
        case .search, .walletSummary, .filters, .activeWalletSession:
            return 0
        case .tokens, .collectiblePairs:
            switch filter {
            case .all, .defi, .governance, .keyword, .assets, .filter, .attestations:
                return filteredTokens.count
            case .collectiblesOnly:
                return collectiblePairs.count
            }
        }
    }

    static func viewModel(for indexPath: IndexPath, sections: [TokensViewModel.Section], filteredTokens: [TokensViewModel.TokenOrRpcServer], collectiblePairs: [TokensViewModel.CollectiblePairs], tokenImageFetcher: TokenImageFetcher, assetDefinitionStore: AssetDefinitionStore) -> TokensViewModel.ViewModelType {
        switch sections[indexPath.section] {
        case .search, .walletSummary, .filters, .activeWalletSession:
            return .undefined
        case .tokens:
            switch tokenOrServer(at: indexPath, filteredTokens: filteredTokens) {
            case .rpcServer(let server):
                let viewModel = TokenListServerTableViewCellViewModel(server: server, isTopSeparatorHidden: true)

                return .rpcServer(viewModel)
            case .token(let token):
                switch token.type {
                case .nativeCryptocurrency:
                    let viewModel = EthTokenViewCellViewModel(token: token, tokenImageFetcher: tokenImageFetcher)

                    return .nativeCryptocurrency(viewModel)
                case .erc20:
                    let viewModel = FungibleTokenViewCellViewModel(token: token, tokenImageFetcher: tokenImageFetcher)

                    return .fungibleToken(viewModel)
                case .erc721, .erc721ForTickets, .erc1155, .erc875:
                    let viewModel = NonFungibleTokenViewCellViewModel(token: token, tokenImageFetcher: tokenImageFetcher)

                    return .nonFungible(viewModel)
                }
            case .attestation(let attestation):
                return .attestation(AttestationViewCellViewModel(attestation: attestation, assetDefinitionStore: assetDefinitionStore))
            }
        case .collectiblePairs:
            let pair = collectiblePairs[indexPath.row]
            let left = OpenSeaNonFungibleTokenViewCellViewModel(token: pair.left, tokenImageFetcher: tokenImageFetcher)
            let right: OpenSeaNonFungibleTokenViewCellViewModel? = pair.right.flatMap { token in .init(token: token, tokenImageFetcher: tokenImageFetcher) }

            let viewModel = OpenSeaNonFungibleTokenPairTableCellViewModel(leftViewModel: left, rightViewModel: right)

            return .nftCollection(viewModel)
        }
    }

    static func tokenOrServer(at indexPath: IndexPath, filteredTokens: [TokensViewModel.TokenOrRpcServer]) -> TokensViewModel.TokenOrRpcServer {
        return filteredTokens[indexPath.row]
    }

    static func collectiblePairs(filteredTokens: [TokensViewModel.TokenOrRpcServer]) -> [TokensViewModel.CollectiblePairs] {
        let tokens = filteredTokens.compactMap { $0.token }
        return tokens.chunked(into: 2).compactMap { elems -> TokensViewModel.CollectiblePairs? in
            guard let left = elems.first else { return nil }

            let right = elems.last?.contractAddress == left.contractAddress ? nil : elems.last
            return .init(left: left, right: right)
        }
    }

    static func generateDisplayState(tokens: [TokenViewModel], attestations: [Attestation], tokensFilter: TokensFilter, filterInUserInterface: WalletFilter, walletConnectSessions: Int, isSearchActive: Bool, tokenImageFetcher: TokenImageFetcher, assetDefinitionStore: AssetDefinitionStore) -> ([TokensViewModel.SectionViewModel], [TokensViewModel.TokenOrRpcServer], [TokensViewModel.Section]) {
        let filteredTokens = filteredAndSortedTokens(tokens: tokens, attestations: attestations, tokensFilter: tokensFilter, filter: filterInUserInterface)
        let sections = refreshSections(walletConnectSessions: walletConnectSessions, isSearchActive: isSearchActive, filter: filterInUserInterface)
        let sectionsViewModels = buildSectionViewModels(sections: sections, filteredTokens: filteredTokens, collectiblePairs: collectiblePairs(filteredTokens: filteredTokens), filter: filterInUserInterface, tokenImageFetcher: tokenImageFetcher, assetDefinitionStore: assetDefinitionStore)
        return (sectionsViewModels, filteredTokens, sections)
    }
}

fileprivate extension IndexPath {
    var previous: IndexPath {
        IndexPath(row: row - 1, section: section)
    }

    var next: IndexPath {
        IndexPath(row: row - 1, section: section)
    }
}

enum TokenOrAttestation {
    case token(Token)
    case attestation(Attestation)
}
