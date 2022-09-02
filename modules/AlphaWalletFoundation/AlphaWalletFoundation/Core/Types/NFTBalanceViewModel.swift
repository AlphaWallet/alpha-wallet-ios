//
//  NFTBalanceViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.03.2022.
//

import Foundation
import BigInt 

public struct NFTBalanceViewModel: BalanceViewModelType {
    public var ticker: CoinTicker?
    private let token: BalanceRepresentable

    init(token: BalanceRepresentable, ticker: CoinTicker?) {
        self.token = token
        self.ticker = ticker
    }

    public var balance: [TokenBalanceValue] {
        return token.balanceNft
    }

    public var value: BigInt { return token.valueBI }
    public var amount: Double { return Double(nonZeroBalance) }
    var amountString: String { return "\(nonZeroBalance) \(token.symbol)" }
    public var currencyAmount: String? { return nil }
    public var currencyAmountWithoutSymbol: Double? { return nil }
    public var amountFull: String { return "\(nonZeroBalance)" }
    public var amountShort: String { return "\(nonZeroBalance)" }
    public var symbol: String { return token.symbol }

    private var nonZeroBalance: Int {
        let actualBalance = Array(token.balanceNft.filter { isNonZeroBalance($0.balance, tokenType: token.type) })
        return actualBalance.count
    }
}
