// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import AlphaWalletFoundation

struct GasViewModel {
    private let fee: BigUInt
    private let symbol: String
    private let rate: CurrencyRate?
    private let formatter: EtherNumberFormatter

    init(fee: BigUInt, symbol: String, rate: CurrencyRate? = nil, formatter: EtherNumberFormatter = .full) {
        self.fee = fee
        self.symbol = symbol
        self.rate = rate
        self.formatter = formatter
    }

    var feeText: String {
        let gasFee = formatter.string(from: fee)
        let text = "\(gasFee.description) \(symbol)"
        
        guard let rate = rate else { return text }
        
        let formatter = NumberFormatter.fiat(currency: rate.currency)
        if let fee = gasFee.optionalDecimalValue, let feeInFiat = formatter.string(double: rate.value * fee.doubleValue) {
            return text + " (\(feeInFiat))"
        } else {
            return text
        }
    }
}
