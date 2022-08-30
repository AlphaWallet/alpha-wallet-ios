// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public struct Rate {
    let code: String
    let price: Double
}

public struct CurrencyRate {
    let currency: String
    let rates: [Rate]
}
