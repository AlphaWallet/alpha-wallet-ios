//
//  SelectAssetViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.07.2020.
//

import UIKit

class SelectAssetViewModel {
    let filterTokensCoordinator: FilterTokensCoordinator
    var tokens: [TokenObject]
    let tickers: [RPCServer: [AlphaWallet.Address: CoinTicker]]
    let filter: WalletFilter

    lazy var filteredTokens: [TokenObject] = filteredAndSortedTokens()

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

    func item(for row: Int) -> TokenObject {
        return filteredTokens[row]
    }

    func ticker(for token: TokenObject) -> CoinTicker? {
        return tickers[token.server]?[token.contractAddress]
    }

    func accessoryType(_ selectedToken: TokenObject?, indexPath: IndexPath) -> UITableViewCell.AccessoryType {
        guard let selectedToken = selectedToken else { return .none }

        let token = filteredTokens[indexPath.row]

        return selectedToken.isEqual(token) ? .checkmark : .none
    }

    convenience init(tokensViewModel viewModel: TokensViewModel, filterTokensCoordinator: FilterTokensCoordinator, filter: WalletFilter) {
        self.init(filterTokensCoordinator: filterTokensCoordinator, tokens: viewModel.tokens, tickers: viewModel.tickers, filter: filter)
    }

    init(filterTokensCoordinator: FilterTokensCoordinator, tokens: [TokenObject], tickers: [RPCServer: [AlphaWallet.Address: CoinTicker]], filter: WalletFilter) {
        self.filterTokensCoordinator = filterTokensCoordinator
        self.tokens = tokens
        self.tickers = tickers
        self.filter = filter
    }

    private func filteredAndSortedTokens() -> [TokenObject] {
        let displayedTokens = filterTokensCoordinator.filterTokens(tokens: tokens, filter: filter)
        return filterTokensCoordinator.sortDisplayedTokens(tokens: displayedTokens)
    }
}
