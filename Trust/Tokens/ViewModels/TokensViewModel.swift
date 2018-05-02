// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

//Must be a class, and not a struct, otherwise changing `filter` will silently create a copy of TokensViewModel when user taps to change the filter in the UI and break filtering
class TokensViewModel {
    var tokens: [TokenObject] = [] {
        willSet {
			tokens = reorderTokensSoFIFAAtIndex1(tokens: newValue)
        }
    }
    var tickers: [String: CoinTicker]?
    var filter: WalletFilter = .all
    var filteredTokens: [TokenObject] {
        get {
            switch filter {
            case .all:
                return tokens
            case .currencyOnly:
                return tokens.filter { !$0.isStormBird }
            case .assetsOnly:
                return tokens.filter { $0.isStormBird }
            }
        }
    }

    private var amount: String? {
        var totalAmount: Double = 0
        filteredTokens.forEach { token in
            totalAmount += amount(for: token)
        }
        guard totalAmount != 0 else { return "--" }
        return CurrencyFormatter.formatter.string(from: NSNumber(value: totalAmount))
    }

    private func amount(for token: TokenObject) -> Double {
        guard let tickers = tickers else { return 0 }
        guard !token.valueBigInt.isZero, let tickersSymbol = tickers[token.contract] else { return 0 }
        let tokenValue = CurrencyFormatter.plainFormatter.string(from: token.valueBigInt, decimals: token.decimals).doubleValue
        let price = Double(tickersSymbol.price) ?? 0
        return tokenValue * price
    }

    var headerBalance: String? {
        return amount
    }

    var headerBalanceTextColor: UIColor {
        return Colors.black
    }

    var headerBackgroundColor: UIColor {
        return .white
    }

    var headerBalanceFont: UIFont {
        return Fonts.semibold(size: 26)!
    }

    var title: String {
        return R.string.localizable.walletTokensTabbarItemTitle()
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var hasContent: Bool {
        return !filteredTokens.isEmpty
    }

    var numberOfSections: Int {
        return 1
    }

    func numberOfItems(for section: Int) -> Int {
        return filteredTokens.count
    }

    func item(for row: Int, section: Int) -> TokenObject {
        return filteredTokens[row]
    }

    func ticker(for token: TokenObject) -> CoinTicker? {
        return tickers?[token.contract]
    }

    func canDelete(for row: Int, section: Int) -> Bool {
        let token = item(for: row, section: section)
        return token.isCustom && token.contract.lowercased() != Constants.ticketContractAddress.lowercased()
    }

    var footerTextColor: UIColor {
        return Colors.black
    }

    var footerTextFont: UIFont {
        return Fonts.light(size: 15)!
    }

    init(
        tokens: [TokenObject],
        tickers: [String: CoinTicker]?
    ) {
        self.tokens = reorderTokensSoFIFAAtIndex1(tokens: tokens)
        self.tickers = tickers
    }

    //FIFA make the FIFA token be index 1. Can remove the function and replace with the argument when we no longer need this
    private func reorderTokensSoFIFAAtIndex1(tokens: [TokenObject]) -> [TokenObject] {
        let index = tokens.index { $0.address.eip55String == Constants.ticketContractAddress
        }
        if let index = index, tokens.count >= 2 {
            var reorderedTokens = tokens
            let target = reorderedTokens[index]
            reorderedTokens.remove(at: index)
            reorderedTokens.insert(target, at: 1)
            return reorderedTokens
        } else {
            return tokens
        }
    }
}
