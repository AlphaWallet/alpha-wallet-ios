// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

struct GasViewModel {
    private let fee: BigInt
    private let symbol: String
    private let currencyRate: CurrencyRate?
    private let formatter: EtherNumberFormatter

    init(
        fee: BigInt,
        symbol: String,
        currencyRate: CurrencyRate? = nil,
        formatter: EtherNumberFormatter = .full
    ) {
        self.fee = fee
        self.symbol = symbol
        self.currencyRate = currencyRate
        self.formatter = formatter
    }

    var feeText: String {
        let gasFee = formatter.string(from: fee)
        var text = "\(gasFee.description) \(symbol)"

        if let feeInCurrency = currencyRate?.estimate(fee: gasFee, with: symbol) {
            text += " (\(feeInCurrency))"
        }
        return text
    }
}
