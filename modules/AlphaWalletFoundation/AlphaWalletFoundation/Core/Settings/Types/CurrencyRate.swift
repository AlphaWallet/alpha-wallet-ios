// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public struct Rate {
    public let code: String
    public let price: Double
}

public struct CurrencyRate {
    public let currency: String
    public let rates: [Rate]
}
