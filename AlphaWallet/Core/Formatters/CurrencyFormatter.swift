// Copyright SIX DAY LLC. All rights reserved.

import Foundation

extension NumberFormatter {

    static let currency = Formatter(.currency)
    static let usd = Formatter(.usd)

    class Formatter {
        private let formatter: NumberFormatter

        fileprivate init(_ configuration: NumberFormatterConfiguration) {
            formatter = configuration.formatter
        }

        func string(from number: Double) -> String? {
            return formatter.string(from: number as NSNumber)
        } 
    }
}

private enum NumberFormatterConfiguration {
    case usd
    case currency

    var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.roundingMode = .down
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = Constants.formatterFractionDigits
        formatter.maximumFractionDigits = Constants.formatterFractionDigits

        switch self {
        case .currency:
            //TODO support multiple currency values
            formatter.currencyCode = Currency.USD.rawValue
        case .usd:
            formatter.positiveFormat = "0.00" + " " + Constants.Currency.usd
            formatter.negativeFormat = "-0.00" + " " + Constants.Currency.usd
            formatter.currencyCode = String()
        }

        return formatter
    }
}
