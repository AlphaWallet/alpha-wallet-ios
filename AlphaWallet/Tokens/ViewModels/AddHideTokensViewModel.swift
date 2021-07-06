// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import PromiseKit

private enum AddHideTokenSections: Int {
    case availableNewTokens
    case displayedTokens
    case hiddenTokens
    case popularTokens

    var description: String {
        switch self {
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
}

//NOTE: Changed to class to prevent update all ViewModel copies and apply updates only in one place.
class AddHideTokensViewModel {
    private let sections: [AddHideTokenSections] = [.displayedTokens, .hiddenTokens, .popularTokens]
    private let filterTokensCoordinator: FilterTokensCoordinator
    private var tokens: [TokenObject]
    private var allPopularTokens: [PopularToken] = []

    private var displayedTokens: [TokenObject] = []
    private var hiddenTokens: [TokenObject] = []
    private var popularTokens: [PopularToken] = []

    var searchText: String? {
        didSet {
            filter(tokens: tokens)
        }
    }
    private let singleChainTokenCoordinators: [SingleChainTokenCoordinator]

    init(tokens: [TokenObject], filterTokensCoordinator: FilterTokensCoordinator, singleChainTokenCoordinators: [SingleChainTokenCoordinator]) {
        self.tokens = tokens
        self.filterTokensCoordinator = filterTokensCoordinator
        self.singleChainTokenCoordinators = singleChainTokenCoordinators
        
        filter(tokens: tokens)
    }

    func set(allPopularTokens: [PopularToken]) {
        self.allPopularTokens = allPopularTokens

        filter(tokens: tokens)
    }

    var title: String {
        R.string.localizable.walletsAddHideTokensTitle()
    }

    var backgroundColor: UIColor {
        GroupedTable.Color.background
    }

    var numberOfSections: Int {
        sections.count
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
        }
    }

    func canMoveItem(indexPath: IndexPath) -> Bool {
        switch sections[indexPath.section] {
        case .displayedTokens:
            return true
        case .availableNewTokens, .popularTokens, .hiddenTokens:
            return false
        }
    }

    func add(token: TokenObject) {
        if !tokens.contains(token) {
            tokens.append(token)
        }

        filter(tokens: tokens)
    }

    private func singleChainTokenCoordinator(forServer server: RPCServer) -> SingleChainTokenCoordinator? {
        singleChainTokenCoordinators.first { $0.isServer(server) }
    }

    typealias TokenWithIndexToInsert = (token: TokenObject, indexPathToInsert: IndexPath)

    enum ShowHideOperationResult {
        case value(TokenWithIndexToInsert?)
        case promise(Promise<TokenWithIndexToInsert?>)
    }

    func addDisplayed(indexPath: IndexPath) -> ShowHideOperationResult {
        switch sections[indexPath.section] {
        case .displayedTokens, .availableNewTokens:
            break
        case .hiddenTokens:
            let token = hiddenTokens.remove(at: indexPath.row)
            displayedTokens.append(token)

            if let sectionIndex = sections.index(of: .displayedTokens) {
                return .value((token, IndexPath(row: max(0, displayedTokens.count - 1), section: Int(sectionIndex))))
            }
        case .popularTokens:
            let token = popularTokens[indexPath.row]

            let promise = fetchContractDataPromise(forServer: token.server, address: token.contractAddress).then { token -> Promise<TokenWithIndexToInsert?> in
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

    func deleteToken(indexPath: IndexPath) -> ShowHideOperationResult {
        switch sections[indexPath.section] {
        case .displayedTokens:
            let token = displayedTokens.remove(at: indexPath.row)
            hiddenTokens.insert(token, at: 0)

            if let sectionIndex = sections.index(of: .hiddenTokens) {
                return .value((token, IndexPath(row: 0, section: Int(sectionIndex))))
            }
        case .hiddenTokens, .availableNewTokens, .popularTokens:
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
        }
    }

    func displayedToken(indexPath: IndexPath) -> Bool {
        switch sections[indexPath.section] {
        case .displayedTokens:
            return true
        case .availableNewTokens, .popularTokens, .hiddenTokens:
            return false
        }
    }

    func item(atIndexPath indexPath: IndexPath) -> WalletOrPopularToken? {
        switch sections[indexPath.section] {
        case .displayedTokens:
            return .walletToken(displayedTokens[indexPath.row])
        case .hiddenTokens:
            return .walletToken(hiddenTokens[indexPath.row])
        case .availableNewTokens:
            return nil
        case .popularTokens:
            return .popularToken(popularTokens[indexPath.row])
        }
    }

    func moveItem(from: IndexPath, to: IndexPath) -> [TokenObject]? {
        switch sections[from.section] {
        case .displayedTokens:
            let token = displayedTokens.remove(at: from.row)
            displayedTokens.insert(token, at: to.row)

            return displayedTokens
        case .hiddenTokens, .availableNewTokens, .popularTokens:
            return nil
        }
    }

    private func filter(tokens: [TokenObject]) {
        displayedTokens.removeAll()
        hiddenTokens.removeAll()

        let filteredTokens = filterTokensCoordinator.filterTokens(tokens: tokens, filter: .keyword(searchText ?? ""))
        for token in filteredTokens {
            if token.shouldDisplay {
                displayedTokens.append(token)
            } else {
                hiddenTokens.append(token)
            }
        }
        popularTokens = filterTokensCoordinator.filterTokens(tokens: allPopularTokens, walletTokens: tokens, filter: .keyword(searchText ?? ""))
        displayedTokens = filterTokensCoordinator.sortDisplayedTokens(tokens: displayedTokens)
    }

    private func fetchContractDataPromise(forServer server: RPCServer, address: AlphaWallet.Address) -> Promise<TokenObject> {
        guard let coordinator = singleChainTokenCoordinator(forServer: server) else {
            return .init(error: RetrieveSingleChainTokenCoordinator())
        }

        return coordinator.addImportedTokenPromise(forContract: address, onlyIfThereIsABalance: false)
    }

    private struct RetrieveSingleChainTokenCoordinator: Error { }
}
