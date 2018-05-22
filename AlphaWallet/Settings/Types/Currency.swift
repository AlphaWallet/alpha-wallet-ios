// Copyright SIX DAY LLC. All rights reserved.

import UIKit

enum Currency: String {
    case AUD
    case BRL
    case CAD
    case CHF
    case CLP
    case CNY
    case CZK
    case DKK
    case EUR
    case GBP
    case HKD
    case HUF
    case IDR
    case ILS
    case INR
    case JPY
    case KRW
    case MXN
    case MYR
    case NOK
    case NZD
    case PHP
    case PKR
    case PLN
    case RUB
    case SEK
    case SGD
    case THB
    case TRY
    case TWD
    case ZAR
    case USD

    static let allValues = [
        USD,
        EUR,
        GBP,
        AUD,
        RUB,
        BRL,
        CAD,
        CHF,
        CLP,
        CNY,
        CZK,
        DKK,
        HKD,
        HUF,
        IDR,
        ILS,
        INR,
        JPY,
        KRW,
        MXN,
        MYR,
        NOK,
        NZD,
        PHP,
        PKR,
        PLN,
        SEK,
        SGD,
        THB,
        TRY,
        TWD,
        ZAR,
    ]

    init(value: String) {
        self =  Currency(rawValue: value) ?? .USD
    }
}

class CurrencyManager {
}

extension CurrencyManager {
    static func getSymbolForCurrencyCode(code: String) -> String? {
        let locale = NSLocale(localeIdentifier: code)
        return locale.displayName(forKey: NSLocale.Key.identifier, value: code)
    }
}
