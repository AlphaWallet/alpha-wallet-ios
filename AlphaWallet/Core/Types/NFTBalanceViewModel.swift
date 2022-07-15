//
//  NFTBalanceViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.03.2022.
//

import Foundation
import BigInt 

struct NFTBalanceViewModel: BalanceViewModelType {
    var ticker: CoinTicker?
    private let token: BalanceRepresentable

    init(token: BalanceRepresentable, ticker: CoinTicker?) {
        self.token = token
        self.ticker = ticker
    }

    var balance: [TokenBalanceValue] {
        return token.balanceNft
    }

    var value: BigInt { return token.valueBI }
    var amount: Double { return Double(nonZeroBalance) }
    var amountString: String { return "\(nonZeroBalance) \(token.symbol)" }
    var currencyAmount: String? { return nil }
    var currencyAmountWithoutSymbol: Double? { return nil }
    var amountFull: String { return "\(nonZeroBalance)" }
    var amountShort: String { return "\(nonZeroBalance)" }
    var symbol: String { return token.symbol }

    private var nonZeroBalance: Int {
        let actualBalance = Array(token.balanceNft.filter { isNonZeroBalance($0.balance, tokenType: token.type) })
        return actualBalance.count
    }
}
