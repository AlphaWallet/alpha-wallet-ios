// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import RealmSwift

struct CoinTicker: Codable {
    private let id: String
    private let symbol: String
    private let image: String = ""

    let price_usd: String
    let percent_change_24h: String
    let contract: String = Constants.nativeCryptoAddressInDatabase

    lazy var rate: CurrencyRate = {
        CurrencyRate(
            currency: symbol,
            rates: [
                Rate(
                    code: symbol,
                    price: Double(price_usd) ?? 0,
                    contract: contract
                ),
            ]
        )
    }()
}

extension CoinTicker {
    var imageURL: URL? {
        return URL(string: image)
    }
}
