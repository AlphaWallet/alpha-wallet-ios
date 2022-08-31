// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import Combine
import AlphaWalletFoundation

struct AddHideTokensViewModelInput {
    let sortTokensParam: AnyPublisher<SortTokensParam, Never>
    let searchText: AnyPublisher<String?, Never>
    let isSearchActive: AnyPublisher<Bool, Never>
}

struct AddHideTokensViewModelOutput {
    let viewState: AnyPublisher<Void, Never>
}

class AddHideTokensViewModel: ObservableObject {
    private var tokens: [TokenViewModel] = []
    private var allPopularTokens: [PopularToken] = []
    private var displayedTokens: [TokenViewModel] = []
    private var hiddenTokens: [TokenViewModel] = []
    private var popularTokens: [PopularToken] = []
    private let importToken: ImportToken
    private let popularTokensCollection: PopularTokensCollectionType = LocalPopularTokensCollection()
    private let config: Config
    private var cancelable = Set<AnyCancellable>()
    private let tokenCollection: TokenCollection
    private let addToken = PassthroughSubject<Token, Never>()
    private (set) var sortTokensParam: SortTokensParam = .byField(field: .name, direction: .ascending)
    private var searchText: String?
    private var isSearchActive: Bool = false
    
    var sections: [Section] = [.sortingFilters, .displayedTokens, .hiddenTokens, .popularTokens]
    var title: String = R.string.localizable.walletsAddHideTokensTitle()
    var backgroundColor: UIColor = GroupedTable.Color.background

    var numberOfSections: Int {
        sections.count
    }
    private let tokensFilter: TokensFilter

    init(tokenCollection: TokenCollection, tokensFilter: TokensFilter, importToken: ImportToken, config: Config) {
        self.tokenCollection = tokenCollection
        self.importToken = importToken
        self.config = config
        self.tokensFilter = tokensFilter
    }

    func transform(input: AddHideTokensViewModelInput) -> AddHideTokensViewModelOutput {
        input.isSearchActive.sink { [weak self] in
            self?.isSearchActive = $0
        }.store(in: &cancelable)

        let whenTokensHasChanged = PassthroughSubject<Void, Never>()
        tokenCollection.tokenViewModels
            .first() //NOTE: out of current logic we load db snapshot, and not handling updates in changeset
            .sink { [weak self] tokens in
                self?.tokens = tokens
                whenTokensHasChanged.send(())
            }.store(in: &cancelable)

        popularTokensCollection.fetchTokens(for: config.enabledServers)
            .done { [weak self] tokens in
                self?.allPopularTokens = tokens
                whenTokensHasChanged.send(())
            }.cauterize()

        let searchText = input.searchText.handleEvents(receiveOutput: { [weak self] in self?.searchText = $0 })
            .map { _ in }

        let sortTokensParam = input.sortTokensParam.handleEvents(receiveOutput: { [weak self] in self?.sortTokensParam = $0 })
            .map { _ in }

        let viewState = Publishers.Merge4(whenTokensHasChanged, searchText, sortTokensParam, addToken.map { _ in })
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

    func add(token _token: Token) {
        guard let token = tokenCollection.tokenViewModel(for: _token) else { return }
        if !tokens.contains(token) {
            tokens.append(token)
        }

        addToken.send(_token)
    }

    func markTokenAsDisplayed(at indexPath: IndexPath) -> ShowHideTokenResult {
        switch sections[indexPath.section] {
        case .displayedTokens, .availableNewTokens, .sortingFilters:
            break
        case .hiddenTokens:
            let token = hiddenTokens.remove(at: indexPath.row)
            displayedTokens.append(token)

            if let sectionIndex = sections.index(of: .displayedTokens) {
                tokenCollection.mark(token: token, isHidden: false)

                return .value((token, IndexPath(row: max(0, displayedTokens.count - 1), section: Int(sectionIndex))))
            }
        case .popularTokens:
            let token = popularTokens[indexPath.row]
            let promise = importToken
                .importToken(for: token.contractAddress, server: token.server, onlyIfThereIsABalance: false)
                .then { [tokenCollection] _token -> Promise<TokenWithIndexToInsert?> in
                    guard let token = tokenCollection.tokenViewModel(for: _token) else { return .init(error: PMKError.cancelled) }
                    self.popularTokens.remove(at: indexPath.row)
                    self.displayedTokens.append(token)

                    if let sectionIndex = self.sections.index(of: .displayedTokens) {
                        tokenCollection.mark(token: token, isHidden: false)

                        return .value((token, IndexPath(row: max(0, self.displayedTokens.count - 1), section: Int(sectionIndex))))
                    }

                    return .value(nil)
                }

            return .promise(promise)
        }

        return .value(nil)
    }

    func markTokenAsHidden(at indexPath: IndexPath) -> ShowHideTokenResult {
        switch sections[indexPath.section] {
        case .displayedTokens:
            let token = displayedTokens.remove(at: indexPath.row)
            hiddenTokens.insert(token, at: 0)

            if let sectionIndex = sections.index(of: .hiddenTokens) {
                tokenCollection.mark(token: token, isHidden: true)
                
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
            guard token.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) else { return .delete }
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
            let viewModel = WalletTokenViewCellViewModel(token: token, isVisible: isVisible)
            return .walletToken(viewModel)
        case .popularToken(let token):
            let viewModel = PopularTokenViewCellViewModel(token: token, isVisible: isVisible)
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
        sections = AddHideTokensViewModel.functional.availableSectionsToDisplay(displayedTokens: displayedTokens, hiddenTokens: hiddenTokens, popularTokens: popularTokens, isSearchActive: isSearchActive)
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
        case promise(Promise<TokenWithIndexToInsert?>)
    }
}

extension TokenViewModel: TokenIdentifiable { }

extension AddHideTokensViewModel {
    class functional {}
}

extension AddHideTokensViewModel.functional {
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
