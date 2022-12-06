//
//  SelectTokenViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.07.2020.
//

import UIKit
import AlphaWalletFoundation

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

class NFTAssetSelectionViewModel {
    let token: Token
    let tokenHolders: [TokenHolder]
    private var filteredTokenHolders: [TokenHolderWithItsTokenIds] = []

    var filter: AssetFilter = .none {
        didSet {
            filter(tokenHolders: tokenHolders)
        }
    }
    var headerBackgroundColor: UIColor = Configuration.Color.Semantic.defaultViewBackground
    let actions: [NFTAssetSelectionViewModel.ToolbarAction] = [.clear, .selectAll, .send]

    var title: String {
        if tokenSelectionCount > 0 {
            return R.string.localizable.semifungiblesSelectedTokens2(String(tokenSelectionCount))
        } else {
            return R.string.localizable.assetsSelectAssetTitle()
        }
    }

    var backgroundColor: UIColor = Configuration.Color.Semantic.tableViewBackground

    var isSearchActive: Bool = false

    func isActionEnabled(_ action: NFTAssetSelectionViewModel.ToolbarAction) -> Bool {
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
        filteredTokenHolders = NFTAssetSelectionViewModel.functional.filter(tokenHolders: tokenHolders, with: filter)
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
        filteredTokenHolders.enumerated().flatMap { selectAllTokens(for: $0.offset) }
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

    init(token: Token, tokenHolders: [TokenHolder]) {
        self.token = token
        self.tokenHolders = tokenHolders

        filter(tokenHolders: tokenHolders)
    }
}

extension NFTAssetSelectionViewModel {
    class functional { }

    enum ToolbarAction: CaseIterable {
        var isEnabled: Bool {
            return true
        }

        case clear
        case selectAll
        case sell
        case deal
        case send

        var title: String {
            switch self {
            case .clear:
                return R.string.localizable.semifungiblesToolbarClear()
            case .selectAll:
                return R.string.localizable.semifungiblesToolbarSelectAll()
            case .sell:
                return R.string.localizable.semifungiblesToolbarSell()
            case .deal:
                return R.string.localizable.semifungiblesToolbarDeal()
            case .send:
                return R.string.localizable.semifungiblesToolbarSend()
            }
        }
    }
}

extension NFTAssetSelectionViewModel.functional {
    static func filter(tokenHolders: [TokenHolder], with filter: AssetFilter) -> [TokenHolderWithItsTokenIds] {
        switch filter {
        case .keyword(let keyword):
            guard var keyword = keyword, keyword.nonEmpty else {
                return tokenHolders.map { TokenHolderWithItsTokenIds(tokenHolder: $0, tokensIds: $0.tokens.map { $0.id }) }
            }
            keyword = keyword.lowercased()

            return tokenHolders.compactMap { tokenHolder -> TokenHolderWithItsTokenIds? in
                let subTokens = tokenHolder.tokens.filter { $0.name.lowercased().contains(keyword) }
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
