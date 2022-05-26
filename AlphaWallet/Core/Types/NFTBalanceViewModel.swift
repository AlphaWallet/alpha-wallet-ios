//
//  NFTBalanceViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.03.2022.
//

import Foundation
import BigInt

struct NFTBalanceViewModel: BalanceViewModel {
    private (set) var ticker: CoinTicker?
    private let token: Token

    init(token: Token, ticker: CoinTicker?) {
        self.token = token
        self.ticker = ticker
    }

    var value: BigInt { return .zero }
    var amount: Double { return 0.0 }
    var amountString: String { return "0.00 \(token.server.symbol)" }
    var currencyAmount: String? { return nil }
    var currencyAmountWithoutSymbol: Double? { return nil }
    var amountFull: String { return "" }
    var amountShort: String { return "" }
    var symbol: String { return "" }

}
