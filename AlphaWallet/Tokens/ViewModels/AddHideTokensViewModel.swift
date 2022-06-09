// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import Combine

//NOTE: Changed to class to prevent update all ViewModel copies and apply updates only in one place.
class AddHideTokensViewModel: ObservableObject {
    private var tokens: [Token] = []
    private var allPopularTokens: [PopularToken] = []
    private var displayedTokens: [Token] = []
    private var hiddenTokens: [Token] = []
    private var popularTokens: [PopularToken] = []
    private let importToken: ImportToken
    private let popularTokensCollection: PopularTokensCollectionType = LocalPopularTokensCollection()
    private let config: Config
    private var cancelable = Set<AnyCancellable>()
    private let tokenCollection: TokenCollection
    private let assetDefinitionStore: AssetDefinitionStore

    var sortTokensParam: SortTokensParam = .byField(field: .name, direction: .ascending) {
        didSet { filterTokens() }
    }
    var searchText: String? {
        didSet { filterTokens() }
    }

    var isSearchActive: Bool = false
    var sections: [Section] = [.sortingFilters, .displayedTokens, .hiddenTokens, .popularTokens]
    var title: String = R.string.localizable.walletsAddHideTokensTitle()
    var backgroundColor: UIColor = GroupedTable.Color.background

    var numberOfSections: Int {
        sections.count
    }

    init(tokenCollection: TokenCollection, importToken: ImportToken, config: Config, assetDefinitionStore: AssetDefinitionStore) {
        self.assetDefinitionStore = assetDefinitionStore
        self.tokenCollection = tokenCollection
        self.importToken = importToken
        self.config = config
    }

    func viewDidLoad() {
        tokenCollection.tokensViewModel
            .first() //NOTE: out of current logic we load db snapshot, and not handling updates in changeset
            .sink { [weak self] viewModel in
                self?.tokens = viewModel.tokens
                self?.filterTokens()
                self?.objectWillChange.send()
            }.store(in: &cancelable)

        popularTokensCollection.fetchTokens(for: config.enabledServers)
            .done { [weak self] tokens in
                self?.allPopularTokens = tokens
                self?.filterTokens()
                self?.objectWillChange.send()
            }.cauterize()
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
        if !tokens.contains(token) {
            tokens.append(token)
        }

        filterTokens()
        objectWillChange.send()
    } 

    func markTokenAsDisplayed(at indexPath: IndexPath) -> ShowHideTokenResult {
        switch sections[indexPath.section] {
        case .displayedTokens, .availableNewTokens, .sortingFilters:
            break
        case .hiddenTokens:
            let token = hiddenTokens.remove(at: indexPath.row)
            displayedTokens.append(token)

            if let sectionIndex = sections.index(of: .displayedTokens) {
                return .value((token, IndexPath(row: max(0, displayedTokens.count - 1), section: Int(sectionIndex))))
            }
        case .popularTokens:
            let token = popularTokens[indexPath.row]
            let promise = importToken
                .importToken(for: token.contractAddress, server: token.server, onlyIfThereIsABalance: false)
                .then { token -> Promise<TokenWithIndexToInsert?> in
                    self.popularTokens.remove(at: indexPath.row)
                    self.displayedTokens.append(token)

                    if let sectionIndex = self.sections.index(of: .displayedTokens) {
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
            return .delete
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
            let viewModel = WalletTokenViewCellViewModel(token: token, assetDefinitionStore: assetDefinitionStore, isVisible: isVisible)
            return .walletToken(viewModel)
        case .popularToken(let token):
            let viewModel = PopularTokenViewCellViewModel(token: token, isVisible: isVisible)
            return .popularToken(viewModel)
        }
    }

    func moveItem(from: IndexPath, to: IndexPath) -> [Token]? {
        switch sections[from.section] {
        case .displayedTokens:
            let token = displayedTokens.remove(at: from.row)
            displayedTokens.insert(token, at: to.row)

            return displayedTokens
        case .hiddenTokens, .availableNewTokens, .popularTokens, .sortingFilters:
            return nil
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

        let filteredTokens = tokenCollection.tokensFilter.filterTokens(tokens: tokens, filter: .keyword(searchText ?? ""))
        for token in filteredTokens {
            if token.shouldDisplay {
                displayedTokens.append(token)
            } else {
                hiddenTokens.append(token)
            }
        }
        popularTokens = tokenCollection.tokensFilter.filterTokens(tokens: allPopularTokens, walletTokens: tokens, filter: .keyword(searchText ?? ""))
        displayedTokens = tokenCollection.tokensFilter.sortDisplayedTokens(tokens: displayedTokens, sortTokensParam: sortTokensParam)
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

    typealias TokenWithIndexToInsert = (token: Token, indexPathToInsert: IndexPath)

    enum ShowHideTokenResult {
        case value(TokenWithIndexToInsert?)
        case promise(Promise<TokenWithIndexToInsert?>)
    }
}

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
