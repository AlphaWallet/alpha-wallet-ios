// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

extension CurrencyRate {
    public func estimate(fee: String, with symbol: String) -> String? {
        guard let feeInDouble = Double(fee) else {
            return nil
        }
        let symbol = symbol.lowercased()
        guard let price = rates.filter({ $0.code.lowercased() == symbol }).first else {
            return nil
        }
        let formattedFee = Formatter.currency.string(from: price.price * feeInDouble)
        return formattedFee
    }
}
