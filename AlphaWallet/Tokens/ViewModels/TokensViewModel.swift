// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

//Must be a class, and not a struct, otherwise changing `filter` will silently create a copy of TokensViewModel when user taps to change the filter in the UI and break filtering
class TokensViewModel {
    //Must be computed because localization can be overridden by user dynamically
    static var segmentedControlTitles: [String] { WalletFilter.orderedTabs.map { $0.title } }

    private let filterTokensCoordinator: FilterTokensCoordinator
    var tokens: [TokenObject]
    let tickers: [RPCServer: [AlphaWallet.Address: CoinTicker]]
    private var amount: String? {
        var totalAmount: Double = 0
        filteredTokens.forEach { token in
            totalAmount += amount(for: token)
        }
        guard totalAmount != 0 else { return "--" }
        return CurrencyFormatter.formatter.string(from: NSNumber(value: totalAmount))
    }

    var filter: WalletFilter = .all {
        didSet {
            filteredTokens = filteredAndSortedTokens()
        }
    }

    lazy var filteredTokens: [TokenObject] = {
        return filteredAndSortedTokens()
    }()

    var headerBackgroundColor: UIColor {
        return .white
    }

    var title: String {
        return R.string.localizable.walletTokensTabbarItemTitle()
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var shouldShowBackupPromptViewHolder: Bool {
        //TODO show the prompt in both ASSETS and COLLECTIBLES tab too
        switch filter {
        case .all, .currencyOnly, .keyword:
            return true
        case .assetsOnly, .collectiblesOnly:
            return false
        }
    }

    var shouldShowCollectiblesCollectionView: Bool {
        switch filter {
        case .all, .currencyOnly, .assetsOnly, .keyword:
            return false
        case .collectiblesOnly:
            return hasContent
        }
    }

    var hasContent: Bool {
        return !filteredTokens.isEmpty
    }

    func numberOfItems() -> Int {
        return filteredTokens.count
    }

    func item(for row: Int, section: Int) -> TokenObject {
        return filteredTokens[row]
    }

    func ticker(for token: TokenObject) -> CoinTicker? {
        return tickers[token.server]?[token.contractAddress]
    }

    func canDelete(for row: Int, section: Int) -> Bool {
        let token = item(for: row, section: section)
        guard !token.isInvalidated else { return false }
        if token.contractAddress.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
            return false
        }
        return true
    }

    init(filterTokensCoordinator: FilterTokensCoordinator, tokens: [TokenObject], tickers: [RPCServer: [AlphaWallet.Address: CoinTicker]]) {
        self.filterTokensCoordinator = filterTokensCoordinator
        self.tokens = tokens
        self.tickers = tickers
    }

    func markTokenHidden(token: TokenObject) -> Bool {
        if let index = tokens.firstIndex(where: { $0.primaryKey == token.primaryKey }) {
            tokens.remove(at: index)
            filteredTokens = filteredAndSortedTokens()

            return true
        }

        return false
    }

    private func filteredAndSortedTokens() -> [TokenObject] {
        let displayedTokens = filterTokensCoordinator.filterTokens(tokens: tokens, filter: filter)
        return filterTokensCoordinator.sortDisplayedTokens(tokens: displayedTokens)
    }

    func nativeCryptoCurrencyToken(forServer server: RPCServer) -> TokenObject? {
        return tokens.first(where: { $0.primaryKey == TokensDataStore.etherToken(forServer: .main).primaryKey })
    }

    func amount(for token: TokenObject) -> Double {
        guard let tickers = tickers[token.server] else { return 0 }
        guard !token.valueBigInt.isZero, let tickersSymbol = tickers[token.contractAddress] else { return 0 }
        let tokenValue = CurrencyFormatter.plainFormatter.string(from: token.valueBigInt, decimals: token.decimals).doubleValue
        let price = tickersSymbol.price_usd
        return tokenValue * price
    }

    func convertSegmentedControlSelectionToFilter(_ selection: SegmentedControl.Selection) -> WalletFilter? {
        switch selection {
        case .selected(let index):
            return WalletFilter.filter(fromIndex: index)
        case .unselected:
            return nil
        }
    }
}

fileprivate extension WalletFilter {
    static var orderedTabs: [WalletFilter] {
        return [
            .all,
            .currencyOnly,
            .assetsOnly,
            .collectiblesOnly,
        ]
    }

    static func filter(fromIndex index: UInt) -> WalletFilter? {
        return WalletFilter.orderedTabs.first { $0.selectionIndex == index }
    }

    var title: String {
        switch self {
        case .all:
            return R.string.localizable.aWalletContentsFilterAllTitle()
        case .currencyOnly:
            return R.string.localizable.aWalletContentsFilterCurrencyOnlyTitle()
        case .assetsOnly:
            return R.string.localizable.aWalletContentsFilterAssetsOnlyTitle()
        case .collectiblesOnly:
            return R.string.localizable.aWalletContentsFilterCollectiblesOnlyTitle()
        case .keyword:
            return ""
        }
    }

    var selectionIndex: UInt? {
        //This is safe only because index can't possibly be negative
        return WalletFilter.orderedTabs.firstIndex { $0 == self }.flatMap { UInt($0) }
    }
}
