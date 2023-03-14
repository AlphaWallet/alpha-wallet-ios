//
//  NativecryptoBalanceViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.06.2021.
//

import Foundation
import BigInt

struct NativecryptoBalanceViewModel: BalanceViewModelType {
    private let _balance: BalanceRepresentable

    var ticker: CoinTicker?

    init(balance: BalanceRepresentable, ticker: CoinTicker?) {
        self._balance = balance
        self.ticker = ticker
    }
    var balance: [TokenBalanceValue] { return [] }
    var value: BigUInt { _balance.valueBI }
    var valueDecimal: Decimal { Decimal(bigUInt: value, decimals: _balance.decimals) ?? .zero }

    var amountString: String {
        guard !isZero else { return "0.00 \(_balance.server.symbol)" }
        let balance = EtherNumberFormatter.full.string(from: _balance.valueBI)
        return "\(balance) \(_balance.server.symbol)"
    }

    var amountInFiat: Double? {
        guard let ticker = ticker else { return nil }
        return valueDecimal.doubleValue * ticker.price_usd
    }

    var amountFull: String { return EtherNumberFormatter.plain.string(from: _balance.valueBI) }
    var amountShort: String { return EtherNumberFormatter.short.string(from: _balance.valueBI) }
    var symbol: String { return _balance.server.symbol }
}
