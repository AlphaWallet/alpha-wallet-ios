// Copyright SIX DAY LLC. All rights reserved.

import Foundation

class CurrencyFormatter {
    static var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .down
        //TODO support multiple currency values
        formatter.currencyCode = Currency.USD.rawValue
        formatter.numberStyle = .currency

        return formatter
    }

    static var usdFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .down
        //TODO support multiple currency values
        formatter.numberStyle = .currency
        formatter.positiveFormat = "0.00" + " " + Constants.Currency.usd
        formatter.negativeFormat = "-0.00" + " " + Constants.Currency.usd

        return formatter
    }

    static var plainFormatter: EtherNumberFormatter {
        let formatter = EtherNumberFormatter.full
        formatter.groupingSeparator = ""
        return formatter
    }

    static var shortFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 4
        formatter.roundingMode = .down
        formatter.positiveFormat = "0.0000"
        formatter.negativeFormat = "-0.0000"
        
        return formatter
    }
}
