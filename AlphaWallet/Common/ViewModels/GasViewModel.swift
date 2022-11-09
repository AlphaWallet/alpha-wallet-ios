// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import AlphaWalletFoundation

struct GasViewModel {
    private let fee: BigInt
    private let symbol: String
    private let coinTicker: CoinTicker?
    private let formatter: EtherNumberFormatter

    init(fee: BigInt, symbol: String, coinTicker: CoinTicker? = nil, formatter: EtherNumberFormatter = .full) {
        self.fee = fee
        self.symbol = symbol
        self.coinTicker = coinTicker
        self.formatter = formatter
    }

    var feeText: String {
        let gasFee = formatter.string(from: fee)
        var text = "\(gasFee.description) \(symbol)"
        
        guard let coinTicker = coinTicker else { return text }

        if let fee = gasFee.optionalDecimalValue, let feeInFiat = Formatter.currency.string(from: coinTicker.price_usd * fee.doubleValue) {
            return text + " (\(feeInFiat))"
        } else {
            return text
        }
    }
}
