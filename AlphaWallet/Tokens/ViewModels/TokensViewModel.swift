// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import Combine
import AlphaWalletFoundation

struct TokensViewModelInput {
    let appear: AnyPublisher<Void, Never>
    let pullToRefresh: AnyPublisher<Void, Never>
    let selection: AnyPublisher<TokensViewModel.SelectionSource, Never>
    let keyboard: AnyPublisher<KeyboardChecker.KeyboardState, Never>
}

struct TokensViewModelOutput {
    let viewState: AnyPublisher<TokensViewModel.ViewState, Never>
    let selection: AnyPublisher<Token, Never>
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
    private (set) var tokens: [TokenViewModel] = []
    private (set) var isSearchActive: Bool = false
    private (set) var filter: WalletFilter = .all
    private (set) var walletConnectSessions: Int = 0
    private (set) var sections: [Section] = []
    private var tokenListSection: Section = .tokens
        //TODO: Replace with usage single array of data, instead of using filteredTokens, and collectiblePairs
    private var filteredTokens: [TokenOrRpcServer] = []
    private var collectiblePairs: [CollectiblePairs] {
        let tokens = filteredTokens.compactMap { $0.token }
        return tokens.chunked(into: 2).compactMap { elems -> CollectiblePairs? in
            guard let left = elems.first else { return nil }

            let right = elems.last?.contractAddress == left.contractAddress ? nil : elems.last
            return .init(left: left, right: right)
        }
    }
    private lazy var walletNameFetcher = GetWalletName(domainResolutionService: domainResolutionService)
    private let domainResolutionService: DomainResolutionServiceType
    private let blockiesGenerator: BlockiesGenerator
    private let sectionViewModelsSubject = CurrentValueSubject<[TokensViewModel.SectionViewModel], Never>([])
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
        switch filter {
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
        switch filter {
        case .all, .keyword:
            return true
        case .assets, .collectiblesOnly, .filter, .defi, .governance:
            return false
        }
    }

    var hasContent: Bool {
        return !collectiblePairs.isEmpty
    }

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
        switch sections[section] {
        case .search, .walletSummary, .filters, .activeWalletSession:
            return 0
        case .tokens, .collectiblePairs:
            switch filter {
            case .all, .defi, .governance, .keyword, .assets, .filter:
                return filteredTokens.count
            case .collectiblesOnly:
                return collectiblePairs.count
            }
        }
    }

    init(wallet: Wallet,
         tokensPipeline: TokensProcessingPipeline,
         tokensFilter: TokensFilter,
         walletConnectProvider: WalletConnectProvider,
         walletBalanceService: WalletBalanceService,
         config: Config,
         domainResolutionService: DomainResolutionServiceType,
         blockiesGenerator: BlockiesGenerator,
         assetDefinitionStore: AssetDefinitionStore,
         tokenImageFetcher: TokenImageFetcher,
         serversProvider: ServersProvidable,
         tokensService: TokensService) {

        self.tokensService = tokensService
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
                self?.reloadData()
            }.store(in: &cancellable)

        tokensPipeline.tokenViewModels
            .sink { [weak self] tokens in
                self?.tokens = tokens
                self?.reloadData()
            }.store(in: &cancellable)

        let walletSummary = walletSummary()
        let title = title(input: input.appear)
        let blockieImage = blockieImage(input: input.appear)
        let selection = selection(trigger: input.selection)

        let titleWithListOfBadTokenScriptFiles = Publishers.CombineLatest(title, assetDefinitionStore.listOfBadTokenScriptFiles)
        let viewState = Publishers.CombineLatest4(sectionViewModelsSubject, walletSummary, blockieImage, titleWithListOfBadTokenScriptFiles)
            .map { [weak self] sections, summary, blockiesImage, data -> TokensViewModel.ViewState in
                let isConsoleButtonHidden = data.1.isEmpty

                return TokensViewModel.ViewState(
                    title: data.0,
                    summary: summary,
                    blockiesImage: blockiesImage,
                    isConsoleButtonHidden: isConsoleButtonHidden,
                    isFooterHidden: self?.isFooterHidden ?? true,
                    sections: sections)
            }.removeDuplicates()
            .eraseToAnyPublisher()

        let applyTableInset = applyTableInset(keyboard: input.keyboard)

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
            blockiesGenerator.getBlockieOrEnsAvatarImage(address: wallet.address, fallbackImage: BlockiesImage.defaulBlockieImage)
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

    private func selection(trigger: AnyPublisher<TokensViewModel.SelectionSource, Never>) -> AnyPublisher<Token, Never> {
        trigger.compactMap { [unowned self, tokensService] source -> Token? in
            switch source {
            case .gridItem(let indexPath, let isLeftCardSelected):
                switch self.sections[indexPath.section] {
                case .collectiblePairs:
                    let pair = collectiblePairs[indexPath.row]
                    guard let viewModel: TokenViewModel = isLeftCardSelected ? pair.left : pair.right else { return nil }

                    return tokensService.token(for: viewModel.contractAddress, server: viewModel.server)
                case .tokens, .activeWalletSession, .filters, .search, .walletSummary:
                    return nil
                }
            case .cell(let indexPath):
                let tokenOrServer = self.tokenOrServer(at: indexPath)
                switch (self.sections[indexPath.section], tokenOrServer) {
                case (.tokens, .token(let viewModel)):
                    return tokensService.token(for: viewModel.contractAddress, server: viewModel.server)!
                case (_, _):
                    return nil
                }
            }
        }.eraseToAnyPublisher()
    }

    private var isFooterHidden: Bool {
        !serversProvider.enabledServers.contains(.main)
    }

    func set(isSearchActive: Bool) {
        self.isSearchActive = isSearchActive

        reloadData()
    }

    func set(filter: WalletFilter) {
        self.filter = filter

        reloadData()
    }

    private func tokenOrServer(at indexPath: IndexPath) -> TokenOrRpcServer {
        return filteredTokens[indexPath.row]
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
            }
        }

        switch sections[indexPath.section] {
        case .collectiblePairs, .search, .walletSummary, .filters, .activeWalletSession:
            return nil
        case .tokens:
            return trailingSwipeActionsConfiguration(forRowAt: indexPath)
        }
    }

    private func viewModel(for indexPath: IndexPath) -> ViewModelType {
        switch sections[indexPath.section] {
        case .search, .walletSummary, .filters, .activeWalletSession:
            return .undefined
        case .tokens:
            switch tokenOrServer(at: indexPath) {
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
            }
        case .collectiblePairs:
            let pair = collectiblePairs[indexPath.row]
            let left = OpenSeaNonFungibleTokenViewCellViewModel(token: pair.left, tokenImageFetcher: tokenImageFetcher)
            let right: OpenSeaNonFungibleTokenViewCellViewModel? = pair.right.flatMap { token in .init(token: token, tokenImageFetcher: tokenImageFetcher) }

            let viewModel = OpenSeaNonFungibleTokenPairTableCellViewModel(leftViewModel: left, rightViewModel: right)

            return .nftCollection(viewModel)
        }
    }

    func cellHeight(for indexPath: IndexPath) -> CGFloat {
        switch sections[indexPath.section] {
        case .tokens:
            switch tokenOrServer(at: indexPath) {
            case .rpcServer:
                return DataEntry.Metric.Tokens.headerHeight
            case .token:
                return DataEntry.Metric.Tokens.cellHeight
            }
        case .search, .walletSummary, .filters, .activeWalletSession:
            return DataEntry.Metric.Tokens.cellHeight
        case .collectiblePairs:
            return DataEntry.Metric.Tokens.collectiblePairsHeight
        }
    }

    @discardableResult private func markTokenHidden(token: TokenViewModel) -> Bool {
        tokensService.mark(token: token, isHidden: true)

        if let index = tokens.firstIndex(where: { $0 == token }) {
            tokens.remove(at: index)
            filteredTokens = filteredAndSortedTokens()

            return true
        }

        return false
    }

    func convertSegmentedControlSelectionToFilter(_ selection: ControlSelection) -> WalletFilter? {
        switch selection {
        case .selected(let index):
            return WalletFilter.filter(fromIndex: index)
        case .unselected:
            return nil
        }
    }

    func indexPathArrayForDeletingAt(indexPath current: IndexPath) -> [IndexPath] {
        let canRemoveCurrentItem: Bool = tokenOrServer(at: current).isRemovable
        let canRemovePreviousItem: Bool = current.row > 0 ? tokenOrServer(at: current.previous).isRemovable : false
        let canRemoveNextItem: Bool = {
            guard (current.row + 1) < filteredTokens.count else { return false }
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

    private func reloadData() {
        filteredTokens = filteredAndSortedTokens()
        refreshSections(walletConnectSessions: walletConnectSessions)

        let sections = buildSectionViewModels()
        sectionViewModelsSubject.send(sections)
    }

    private func buildSectionViewModels() -> [TokensViewModel.SectionViewModel] {
        return sections.enumerated().map { (sectionIndex, section) -> TokensViewModel.SectionViewModel in
            guard numberOfItems(for: sectionIndex) > 0 else {
                return TokensViewModel.SectionViewModel(section: section, views: [])
            }

            let viewModels = (0 ..< numberOfItems(for: sectionIndex)).map { row -> ViewModelType in
                let indexPath = IndexPath(row: row, section: sectionIndex)
                return self.viewModel(for: indexPath)
            }

            return TokensViewModel.SectionViewModel(section: section, views: viewModels)
        }
    }

    private func filteredAndSortedTokens() -> [TokenOrRpcServer] {
        let displayedTokens = tokensFilter.filterTokens(tokens: tokens, filter: filter)
        let tokens = tokensFilter.sortDisplayedTokens(tokens: displayedTokens)
        switch filter {
        case .all, .filter, .defi, .governance, .assets, .keyword:
            return TokensViewModel.functional.groupTokensByServers(tokens: tokens)
        case .collectiblesOnly:
            return tokens.map { .token($0) }
        }
    }

    private func refreshSections(walletConnectSessions count: Int) {
        let varyTokenOrCollectiblePeirsSection: Section = {
            switch filter {
            case .all, .defi, .governance, .keyword, .assets, .filter:
                return .tokens
            case .collectiblesOnly:
                return .collectiblePairs
            }
        }()

        if isSearchActive {
            sections = [varyTokenOrCollectiblePeirsSection]
        } else {
            let initialSections: [Section]

            if count == .zero {
                initialSections = [.walletSummary, .filters, .search]
            } else {
                initialSections = [.walletSummary, .filters, .search, .activeWalletSession]
            }
            sections = initialSections + [varyTokenOrCollectiblePeirsSection]
        }
        tokenListSection = varyTokenOrCollectiblePeirsSection
    }
}
// swiftlint:enable type_body_length

extension TokensViewModel {
    enum HideTokenResult {
        case success(indexPaths: [IndexPath])
        case failure
    }

    enum TokenOrRpcServer {
        case token(TokenViewModel)
        case rpcServer(RPCServer)

        var token: TokenViewModel? {
            switch self {
            case .rpcServer:
                return nil
            case .token(let token):
                return token
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
            }
        }

        var isRemovable: Bool {
            switch self {
            case .rpcServer:
                return false
            case .token:
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
        case undefined
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
        let sections: [TokensViewModel.SectionViewModel]
    }
}

extension TokensViewModel.ViewState: Hashable { }
extension TokensViewModel.SectionViewModel: Hashable { }
extension TokensViewModel.ViewModelType: Hashable { }

extension WalletFilter {
    static var orderedTabs: [WalletFilter] {
        return [
            .all,
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
        }
    }
}

extension TokensViewModel {
    enum functional {}
}

extension TokensViewModel.functional {
    static func groupTokensByServers(tokens: [TokenViewModel]) -> [TokensViewModel.TokenOrRpcServer] {
        var servers: [RPCServer] = []
        var results: [TokensViewModel.TokenOrRpcServer] = []

        for each in tokens {
            guard !servers.contains(each.server) else { continue }
            servers.append(each.server)
        }

        for each in servers {
            let tokens = tokens.filter { $0.server == each }.map { TokensViewModel.TokenOrRpcServer.token($0) }
            guard !tokens.isEmpty else { continue }

            results.append(.rpcServer(each))
            results.append(contentsOf: tokens)
        }

        return results
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
