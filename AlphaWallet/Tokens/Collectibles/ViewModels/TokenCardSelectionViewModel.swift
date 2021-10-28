//
//  SelectTokenViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.07.2020.
//

import UIKit

typealias TokenHolderSelection = (tokenId: TokenId, tokenHolder: TokenHolder)

struct TokenHolderWithItsTokenIds {
    let tokenHolder: TokenHolder
    let tokensIds: [TokenId]

    init(tokenHolder: TokenHolder, tokensIds: [TokenId]) {
        self.tokenHolder = tokenHolder
        self.tokensIds = tokensIds
    }
}

enum AssetFilter {
    case keyword(String?)
    case none
}

class TokenCardSelectionViewModel {
    let tokenObject: TokenObject
    let tokenHolders: [TokenHolder]
    private var filteredTokenHolders: [TokenHolderWithItsTokenIds] = []

    var filter: AssetFilter = .none {
        didSet {
            filter(tokenHolders: tokenHolders)
        }
    }
    var headerBackgroundColor: UIColor = Colors.appWhite
    let actions: [TokenCardSelectionViewController.ToolbarAction] = [.clear, .selectAll, .send]

    var navigationTitle: String {
        if tokenSelectionCount > 0 {
            return R.string.localizable.semifungiblesSelectedTokens2(String(tokenSelectionCount))
        } else {
            return R.string.localizable.assetsSelectAssetTitle()
        }
    }

    var backgroundColor: UIColor = GroupedTable.Color.background

    var isSearchActive: Bool = false

    func isActionEnabled(_ action: TokenCardSelectionViewController.ToolbarAction) -> Bool {
        switch action {
        case .clear, .selectAll:
            return true
        case .deal, .sell, .send:
            return tokenHolders.contains(where: { $0.totalSelectedCount > 0 })
        }
    }
    var numberOfSections: Int {
        filteredTokenHolders.count
    }

    func numberOfTokens(section: Int) -> Int {
        return filteredTokenHolders[section].tokensIds.count
    }

    func titleForTokenHolder(section: Int) -> String {
        return filteredTokenHolders[section].tokenHolder.name
    }

    private func filter(tokenHolders: [TokenHolder]) {
        filteredTokenHolders = TokenCardSelectionViewModel.functional.filter(tokenHolders: tokenHolders, with: filter)
    }

    func tokenHolderSelection(indexPath: IndexPath) -> TokenHolderSelection {
        let pair = filteredTokenHolders[indexPath.section]

        return (pair.tokensIds[indexPath.row], pair.tokenHolder)
    }

    func selectableTokenHolder(at section: Int) -> TokenHolder {
        return filteredTokenHolders[section].tokenHolder
    }

    func selectTokens(indexPath: IndexPath, selectedAmount: Int) {
        let selection = tokenHolderSelection(indexPath: indexPath)
        selection.tokenHolder.select(with: .token(tokenId: selection.tokenId, amount: selectedAmount))
    }

    func selectAllTokens(for section: Int) -> [IndexPath] {
        let tokenHolder = self.filteredTokenHolders[section]
        guard !tokenHolder.tokensIds.isEmpty else { return [] }
        tokenHolder.tokenHolder.select(with: .all)

        return tokenHolder.tokensIds.enumerated().map { IndexPath(row: $0.offset, section: section) }
    }

    func selectAllTokens() -> [IndexPath] {
        filteredTokenHolders.enumerated().flatMap { pair -> [IndexPath] in
            selectAllTokens(for: pair.offset)
        }
    }

    func unselectAll() -> [IndexPath] {
        var indexPaths: [IndexPath] = []
        for (index, tokenHolder) in filteredTokenHolders.enumerated() {
            tokenHolder.tokenHolder.unselect(with: .all)

            indexPaths += tokenHolder.tokensIds.enumerated().map {
                IndexPath(row: $0.offset, section: index)
            }
        }

        return indexPaths
    }

    private var tokenSelectionCount: Int {
        var sum: Int = 0
        for tokenHolder in filteredTokenHolders {
            sum += tokenHolder.tokenHolder.totalSelectedCount
        }

        return sum
    }

    init(tokenObject: TokenObject, tokenHolders: [TokenHolder]) {
        self.tokenObject = tokenObject
        self.tokenHolders = tokenHolders

        filter(tokenHolders: tokenHolders)
    }
}

extension TokenCardSelectionViewModel {
    class functional { }
}

extension TokenCardSelectionViewModel.functional {
    static func filter(tokenHolders: [TokenHolder], with filter: AssetFilter) -> [TokenHolderWithItsTokenIds] {
        switch filter {
        case .keyword(let keyword):
            guard var keyword = keyword, keyword.nonEmpty else {
                return tokenHolders.map { TokenHolderWithItsTokenIds(tokenHolder: $0, tokensIds: $0.tokens.map { $0.id }) }
            }
            keyword = keyword.lowercased()

            return tokenHolders.compactMap { tokenHolder -> TokenHolderWithItsTokenIds? in
                let subTokens = tokenHolder.tokens.filter({ $0.name.lowercased().contains(keyword) })
                if subTokens.isEmpty {
                    if tokenHolder.name.contains(keyword) {
                        return TokenHolderWithItsTokenIds(tokenHolder: tokenHolder, tokensIds: [])
                    } else {
                        return nil
                    }
                } else {
                    return TokenHolderWithItsTokenIds(tokenHolder: tokenHolder, tokensIds: subTokens.map { $0.id })
                }
            }
        case .none:
            return tokenHolders.map { TokenHolderWithItsTokenIds(tokenHolder: $0, tokensIds: $0.tokens.map { $0.id }) }
        }
    }
}
