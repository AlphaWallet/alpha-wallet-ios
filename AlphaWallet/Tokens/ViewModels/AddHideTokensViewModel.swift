// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletFoundation

struct AddHideTokensViewModelInput {
    let sortTokensParam: AnyPublisher<SortTokensParam, Never>
    let searchText: AnyPublisher<String?, Never>
    let isSearchActive: AnyPublisher<Bool, Never>
}

struct AddHideTokensViewModelOutput {
    let viewState: AnyPublisher<Void, Never>
}

final class AddHideTokensViewModel {
    private var tokens: [TokenViewModel] = []
    private var allPopularTokens: [PopularToken] = []
    private var displayedTokens: [TokenViewModel] = []
    private var hiddenTokens: [TokenViewModel] = []
    private var popularTokens: [PopularToken] = []
    private let sessionsProvider: SessionsProvider
    private let popularTokensCollection: PopularTokensCollectionType
    private var cancelable = Set<AnyCancellable>()
    private let tokenCollection: TokensProcessingPipeline
    private let addToken = PassthroughSubject<Void, Never>()
    private (set) var sortTokensParam: SortTokensParam = .byField(field: .name, direction: .ascending)
    private var searchText: String?
    private var isSearchActive: Bool = false
    private let tokensFilter: TokensFilter
    private let tokenImageFetcher: TokenImageFetcher
    private let tokensService: TokensService

    var sections: [Section] = [.sortingFilters, .displayedTokens, .hiddenTokens, .popularTokens]
    var title: String = R.string.localizable.walletsAddHideTokensTitle()

    var numberOfSections: Int {
        sections.count
    }

    init(tokenCollection: TokensProcessingPipeline,
         tokensFilter: TokensFilter,
         sessionsProvider: SessionsProvider,
         tokenImageFetcher: TokenImageFetcher,
         tokensService: TokensService) {

        self.tokensService = tokensService
        self.tokenImageFetcher = tokenImageFetcher
        self.tokenCollection = tokenCollection
        self.sessionsProvider = sessionsProvider
        self.tokensFilter = tokensFilter
        self.popularTokensCollection = PopularTokensCollection(
            servers: sessionsProvider.sessions.map { Array($0.keys) }.eraseToAnyPublisher(),
            tokensUrl: PopularTokensCollection.bundleLocatedTokensUrl)
    }

    func transform(input: AddHideTokensViewModelInput) -> AddHideTokensViewModelOutput {
        input.isSearchActive
            .sink { [weak self] in self?.isSearchActive = $0 }
            .store(in: &cancelable)

        let whenTokensHasChanged = PassthroughSubject<Void, Never>()
        tokenCollection.tokenViewModels
            .first() //NOTE: out of current logic we load db snapshot, and not handling updates in changeset
            .sink { [weak self] tokens in
                self?.tokens = tokens
                whenTokensHasChanged.send(())
            }.store(in: &cancelable)

        popularTokensCollection.fetchTokens()
            .sink(receiveCompletion: { _ in

            }, receiveValue: { [weak self] tokens in
                self?.allPopularTokens = tokens
                whenTokensHasChanged.send(())
            }).store(in: &cancelable)

        let searchText = input.searchText
            .handleEvents(receiveOutput: { [weak self] in self?.searchText = $0 })
            .mapToVoid()

        let sortTokensParam = input.sortTokensParam
            .handleEvents(receiveOutput: { [weak self] in self?.sortTokensParam = $0 })
            .mapToVoid()

        let viewState = Publishers.Merge4(whenTokensHasChanged, searchText, sortTokensParam, addToken)
            .handleEvents(receiveOutput: { [weak self] _ in self?.filterTokens() })

        return .init(viewState: viewState.eraseToAnyPublisher())
    }

    func titleForSection(_ section: Int) -> String {
        sections[section].description
    }

    func numberOfItems(_ section: Int) -> Int {
        switch sections[section] {
        case .displayedTokens:
            return displayedTokens.count
        case .hiddenTokens:
            return hiddenTokens.count
        case .availableNewTokens:
            return 0
        case .popularTokens:
            return popularTokens.count
        case .sortingFilters:
            return 0
        }
    }

    func canMoveItem(indexPath: IndexPath) -> Bool {
        switch sections[indexPath.section] {
        case .displayedTokens:
            return true
        case .availableNewTokens, .popularTokens, .hiddenTokens, .sortingFilters:
            return false
        }
    }

    func add(token: Token) {
        Task { @MainActor in
            guard let token = await tokenCollection.tokenViewModel(for: token) else { return }
            if !tokens.contains(token) {
                tokens.append(token)
            }

            addToken.send(())
        }
    }

    private func mark(token: TokenViewModel, isHidden: Bool) {
        tokensService.mark(token: token, isHidden: isHidden)

        if let index = tokens.firstIndex(where: { $0 == token }) {
            tokens[index] = token.override(shouldDisplay: !isHidden)
        }
    }

    func markTokenAsDisplayed(at indexPath: IndexPath) -> ShowHideTokenResult {
        switch sections[indexPath.section] {
        case .displayedTokens, .availableNewTokens, .sortingFilters:
            break
        case .hiddenTokens:
            let token = hiddenTokens.remove(at: indexPath.row)
            displayedTokens.append(token)

            if let sectionIndex = sections.firstIndex(of: .displayedTokens) {
                mark(token: token, isHidden: false)

                return .value((token, IndexPath(row: max(0, displayedTokens.count - 1), section: Int(sectionIndex))))
            }
        case .popularTokens:
            let token = popularTokens[indexPath.row]
            guard let session = sessionsProvider.session(for: token.server) else {
                return .value(nil)
            }
            let publisher = session.importToken
                .importToken(for: token.contractAddress, onlyIfThereIsABalance: false)
                .flatMap { [tokensService, tokenCollection] _token -> AnyPublisher<TokenWithIndexToInsert?, ImportToken.ImportTokenError> in
                    asFutureThrowable {
                        guard let token = await tokenCollection.tokenViewModel(for: _token) else {
                            throw ImportToken.ImportTokenError.notContractOrFailed(.delegateContracts([_token.addressAndRPCServer]))
                        }
                        self.popularTokens.remove(at: indexPath.row)
                        self.displayedTokens.append(token)

                        if let sectionIndex = self.sections.firstIndex(of: .displayedTokens) {
                            tokensService.mark(token: token, isHidden: false)

                            return (token, IndexPath(row: max(0, self.displayedTokens.count - 1), section: Int(sectionIndex)))
                        }

                        return nil
                    }
                        .mapError { ImportToken.ImportTokenError.internal(error: $0) }
                        .eraseToAnyPublisher()
                }.eraseToAnyPublisher()

            return .publisher(publisher)
        }

        return .value(nil)
    }

    func markTokenAsHidden(at indexPath: IndexPath) -> ShowHideTokenResult {
        switch sections[indexPath.section] {
        case .displayedTokens:
            let token = displayedTokens.remove(at: indexPath.row)
            hiddenTokens.insert(token, at: 0)

            if let sectionIndex = sections.firstIndex(of: .hiddenTokens) {
                mark(token: token, isHidden: true)

                return .value((token, IndexPath(row: 0, section: Int(sectionIndex))))
            }
        case .hiddenTokens, .availableNewTokens, .popularTokens, .sortingFilters:
            break
        }

        return .value(nil)
    }

    func editingStyle(indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        switch sections[indexPath.section] {
        case .displayedTokens:
            let token = displayedTokens[indexPath.row]
            guard token.contractAddress == Constants.nativeCryptoAddressInDatabase else { return .delete }
            return .none
        case .availableNewTokens, .popularTokens, .hiddenTokens:
            return .insert
        case .sortingFilters:
            return .none
        }
    }

    func viewModel(for indexPath: IndexPath) -> ViewModelType {
        guard let token = token(at: indexPath) else { return .undefined }
        let isVisible = displayedToken(indexPath: indexPath)

        switch token {
        case .walletToken(let token):
            let viewModel = WalletTokenViewCellViewModel(token: token, isVisible: isVisible, tokenImageFetcher: tokenImageFetcher)
            return .walletToken(viewModel)
        case .popularToken(let token):
            let viewModel = PopularTokenViewCellViewModel(token: token, isVisible: isVisible, tokenImageFetcher: tokenImageFetcher)
            return .popularToken(viewModel)
        }
    }

    private func displayedToken(indexPath: IndexPath) -> Bool {
        switch sections[indexPath.section] {
        case .displayedTokens:
            return true
        case .availableNewTokens, .popularTokens, .hiddenTokens, .sortingFilters:
            return false
        }
    }

    private func token(at indexPath: IndexPath) -> WalletOrPopularToken? {
        switch sections[indexPath.section] {
        case .displayedTokens:
            return .walletToken(displayedTokens[indexPath.row])
        case .hiddenTokens:
            return .walletToken(hiddenTokens[indexPath.row])
        case .availableNewTokens, .sortingFilters:
            return nil
        case .popularTokens:
            return .popularToken(popularTokens[indexPath.row])
        }
    }

    private func filterTokens() {
        displayedTokens.removeAll()
        hiddenTokens.removeAll()

        let filteredTokens: [TokenViewModel] = tokensFilter.filterTokens(tokens: tokens, filter: .keyword(searchText ?? ""))
        for token in filteredTokens {
            if token.shouldDisplay {
                displayedTokens.append(token)
            } else {
                hiddenTokens.append(token)
            }
        }
        popularTokens = tokensFilter.filterTokens(tokens: allPopularTokens, walletTokens: tokens, filter: .keyword(searchText ?? ""))
        displayedTokens = tokensFilter.sortDisplayedTokens(tokens: displayedTokens, sortTokensParam: sortTokensParam)
        sections = functional.availableSectionsToDisplay(displayedTokens: displayedTokens, hiddenTokens: hiddenTokens, popularTokens: popularTokens, isSearchActive: isSearchActive)
    }
}

extension AddHideTokensViewModel {
    enum Section: Int {
        case sortingFilters
        case availableNewTokens
        case displayedTokens
        case hiddenTokens
        case popularTokens

        var description: String {
            switch self {
            case .sortingFilters:
                return String()
            case .availableNewTokens:
                return R.string.localizable.addHideTokensSectionNewTokens()
            case .displayedTokens:
                return R.string.localizable.addHideTokensSectionDisplayedTokens()
            case .hiddenTokens:
                return R.string.localizable.addHideTokensSectionHiddenTokens()
            case .popularTokens:
                return R.string.localizable.addHideTokensSectionPopularTokens()
            }
        }

        static var enabledSectins: [Section] {
            [.sortingFilters, .displayedTokens, .hiddenTokens, .popularTokens]
        }
    }

    enum ViewModelType {
        case walletToken(WalletTokenViewCellViewModel)
        case popularToken(PopularTokenViewCellViewModel)
        case undefined
    }

    typealias TokenWithIndexToInsert = (token: TokenViewModel, indexPathToInsert: IndexPath)

    enum ShowHideTokenResult {
        case value(TokenWithIndexToInsert?)
        case publisher(AnyPublisher<TokenWithIndexToInsert?, ImportToken.ImportTokenError>)
    }
}

extension TokenViewModel: TokenIdentifiable { }

extension AddHideTokensViewModel {
    enum functional {}
}

fileprivate extension AddHideTokensViewModel.functional {
    static func availableSectionsToDisplay(displayedTokens: [Any], hiddenTokens: [Any], popularTokens: [Any], isSearchActive: Bool) -> [AddHideTokensViewModel.Section] {
        if isSearchActive {
            var sections: [AddHideTokensViewModel.Section] = []
            if !displayedTokens.isEmpty {
                sections.append(.displayedTokens)
            }
            if !hiddenTokens.isEmpty {
                sections.append(.hiddenTokens)
            }
            if !popularTokens.isEmpty {
                sections.append(.popularTokens)
            }
            return sections
        } else {
            return AddHideTokensViewModel.Section.enabledSectins
        }
    }
}
