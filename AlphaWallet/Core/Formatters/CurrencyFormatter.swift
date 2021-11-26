// Copyright SIX DAY LLC. All rights reserved.

import Foundation

extension NumberFormatter {

    static let currency = Formatter(.currency)
    static let usd = Formatter(.usd(format: .withTrailingCurrency))
    static let percent = Formatter(.percent)
    static let shortCrypto = Formatter(.shortCrypto)

    static func usd(format: USDFormat) -> Formatter {
        Formatter(.usd(format: format))
    }
    
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

enum USDFormat {
    case withTrailingCurrency
    case withLeadingCurrencySymbol(positiveSymbol: String)

    static var priceChangeFormat: USDFormat {
        .withLeadingCurrencySymbol(positiveSymbol: "")
    }

    static var fiatFormat: USDFormat {
        .withLeadingCurrencySymbol(positiveSymbol: "")
    }
}

private enum NumberFormatterConfiguration {
    case usd(format: USDFormat)
    case currency
    case percent
    case shortCrypto

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
        case .usd(let format):
            switch format {
            case .withTrailingCurrency:
                formatter.positiveFormat = "0.00" + " " + Constants.Currency.usd
                formatter.negativeFormat = "0.00" + " " + Constants.Currency.usd
            case .withLeadingCurrencySymbol(let positiveSymbol):
                formatter.positiveFormat = positiveSymbol + "$0.00"
                formatter.negativeFormat = "-$0.00"
            }

            formatter.currencyCode = String()
        case .percent:
            formatter.positiveFormat = "0.00"
            formatter.negativeFormat = "-0.00"
            formatter.numberStyle = .percent
        case .shortCrypto:
            formatter.positiveFormat = "0.0000"
            formatter.negativeFormat = "-0.0000"
            formatter.numberStyle = .none
            formatter.minimumFractionDigits = Constants.etherFormatterFractionDigits
            formatter.maximumFractionDigits = Constants.etherFormatterFractionDigits
        }

        return formatter
    }
}
