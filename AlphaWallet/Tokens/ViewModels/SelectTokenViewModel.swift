//
//  SelectTokenViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.07.2020.
//

import UIKit

class SelectTokenViewModel {
    let tokensFilter: TokensFilter
    var tokens: [Token]
    let filter: WalletFilter

    lazy var filteredTokens: [Token] = filteredAndSortedTokens()

    var headerBackgroundColor: UIColor {
        return .white
    }

    var title: String {
        return R.string.localizable.assetsSelectAssetTitle()
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    func numberOfItems() -> Int {
        return filteredTokens.count
    }

    func item(for row: Int) -> Token {
        return filteredTokens[row]
    }

    func accessoryType(_ selectedToken: Token?, indexPath: IndexPath) -> UITableViewCell.AccessoryType {
        guard let selectedToken = selectedToken else { return .none }

        let token = filteredTokens[indexPath.row]

        return selectedToken == token ? .checkmark : .none
    }

    convenience init(tokensViewModel viewModel: TokensViewModel, tokensFilter: TokensFilter, filter: WalletFilter) {
        self.init(tokensFilter: tokensFilter, tokens: viewModel.tokens, filter: filter)
    }

    init(tokensFilter: TokensFilter, tokens: [Token], filter: WalletFilter) {
        self.tokensFilter = tokensFilter
        self.tokens = tokens
        self.filter = filter
    }

    private func filteredAndSortedTokens() -> [Token] {
        let displayedTokens = tokensFilter.filterTokens(tokens: tokens, filter: filter)
        return tokensFilter.sortDisplayedTokens(tokens: displayedTokens)
    }
}
