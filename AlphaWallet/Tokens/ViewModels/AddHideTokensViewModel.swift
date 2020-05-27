// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

private enum AddHideTokenSections: Int {
    case availableNewTokens
    case displayedTokens
    case hiddenTokens

    var description: String {
        switch self {
        case .availableNewTokens:
            return R.string.localizable.addHideTokensSectionNewTokens()
        case .displayedTokens:
            return R.string.localizable.addHideTokensSectionDisplayedTokens()
        case .hiddenTokens:
            return R.string.localizable.addHideTokensSectionHiddenTokens()
        }
    }
}

struct AddHideTokensViewModel {
    private let sections: [AddHideTokenSections] = [.displayedTokens, .hiddenTokens]
    private let filterTokensCoordinator: FilterTokensCoordinator
    private var tokens: [TokenObject]
    private var tickers: [RPCServer: [AlphaWallet.Address: CoinTicker]]
    private var displayedTokens: [TokenObject] = []
    private var hiddenTokens: [TokenObject] = []

    var searchText: String? {
        didSet {
            filter(tokens: tokens)
        }
    }

    init(tokens: [TokenObject], tickers: [RPCServer: [AlphaWallet.Address: CoinTicker]], filterTokensCoordinator: FilterTokensCoordinator) {
        self.tickers = tickers
        self.tokens = tokens
        self.filterTokensCoordinator = filterTokensCoordinator

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
        }
    }

    func canMoveItem(indexPath: IndexPath) -> Bool {
        switch sections[indexPath.section] {
        case .displayedTokens:
            return true
        case .availableNewTokens:
            return false
        case .hiddenTokens:
            return false
        }
    }

    mutating func update(tokensViewModel viewModel: TokensViewModel) {
        tickers = viewModel.tickers
        tokens = viewModel.tokens

        filter(tokens: tokens)
    }

    mutating func addDisplayed(indexPath: IndexPath) -> (token: TokenObject, indexPathToInsert: IndexPath)? {
        switch sections[indexPath.section] {
        case .displayedTokens:
            break
        case .hiddenTokens:
            let token = hiddenTokens.remove(at: indexPath.row)
            displayedTokens.append(token)

            if let sectionIndex = sections.index(of: .displayedTokens) {
                return (token, IndexPath(row: max(0, displayedTokens.count - 1), section: Int(sectionIndex)))
            }
        case .availableNewTokens:
            break
        }

        return nil
    }

    mutating func deleteToken(indexPath: IndexPath) -> (token: TokenObject, indexPathToInsert: IndexPath)? {
        switch sections[indexPath.section] {
        case .displayedTokens:
            let token = displayedTokens.remove(at: indexPath.row)
            hiddenTokens.insert(token, at: 0)

            if let sectionIndex = sections.index(of: .hiddenTokens) {
                return (token, IndexPath(row: 0, section: Int(sectionIndex)))
            }
        case .hiddenTokens:
            break
        case .availableNewTokens:
            break
        }

        return nil
    }

    func editingStyle(indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        switch sections[indexPath.section] {
        case .displayedTokens:
            return .delete
        case .availableNewTokens:
            return .insert
        case .hiddenTokens:
            return .insert
        }
    }

    func displayedToken(indexPath: IndexPath) -> Bool {
        switch sections[indexPath.section] {
        case .displayedTokens:
            return true
        case .availableNewTokens:
            return false
        case .hiddenTokens:
            return false
        }
    }

    func item(atIndexPath indexPath: IndexPath) -> TokenObject? {
        switch sections[indexPath.section] {
        case .displayedTokens:
            return displayedTokens[indexPath.row]
        case .hiddenTokens:
            return hiddenTokens[indexPath.row]
        case .availableNewTokens:
            return nil
        }
    }

    mutating func moveItem(from: IndexPath, to: IndexPath) -> [TokenObject]? {
        switch sections[from.section] {
        case .displayedTokens:
            let token = displayedTokens.remove(at: from.row)
            displayedTokens.insert(token, at: to.row)

            return displayedTokens
        case .hiddenTokens:
            return nil
        case .availableNewTokens:
            return nil
        }
    }

    func ticker(for token: TokenObject) -> CoinTicker? {
        return tickers[token.server]?[token.contractAddress]
    }

    private mutating func filter(tokens: [TokenObject]) {
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
        displayedTokens = filterTokensCoordinator.sortDisplayedTokens(tokens: displayedTokens)
    }
}
