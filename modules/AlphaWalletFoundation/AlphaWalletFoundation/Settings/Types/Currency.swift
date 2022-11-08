// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public enum Currency: String, CaseIterable {
    private static let outputLocale = NSLocale(localeIdentifier: "en_US_POSIX")
    
    case AUD
    case UAH
    case USD
    case EUR
    case JPY
    case CNY
    case PLN
    case TRY
    case GBP
    case TWD
    case SGD
    case NZD
    case CAD

    public init(code: String) {
        self = Currency(rawValue: code) ?? .USD
    }

    public var name: String? {
        return Currency.outputLocale.displayName(forKey: NSLocale.Key.currencyCode, value: code)
    }

    public var code: String {
        return rawValue
    }
}
