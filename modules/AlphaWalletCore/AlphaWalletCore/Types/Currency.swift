// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

public enum Currency: String, CaseIterable, Codable {
    private static let outputLocale = NSLocale(localeIdentifier: "en_US_POSIX")

    public static var `default`: Currency = .USD

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
        self = Currency(rawValue: code) ?? Currency.default
    }

    public var name: String? {
        return Currency.outputLocale.displayName(forKey: NSLocale.Key.currencyCode, value: code)
    }

    public var code: String {
        return rawValue
    }

    public var symbol: String {
        switch self {
        case .USD, .AUD, .TWD, .SGD, .NZD, .CAD: return "$"
        case .GBP: return "£"
        case .UAH: return "₴"
        case .EUR: return "€"
        case .JPY: return "¥"
        case .CNY: return "¥"
        case .PLN: return "zł"
        case .TRY: return "₺"
        }
    }
}
