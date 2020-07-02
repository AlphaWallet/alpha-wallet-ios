// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import RealmSwift

struct CoinTicker: Codable {
    private enum CodingKeys: String, CodingKey {
        case price_usd = "current_price", percent_change_24h = "price_change_percentage_24h", id = "id", symbol = "symbol", image = "image"
    }

    private let id: String
    private let symbol: String
    private let image: String = ""

    let price_usd: Double
    let percent_change_24h: Double
    //TODO use AlphaWallet.Address? Note that the containing struct is Codable
    let contract: String = Constants.nativeCryptoAddressInDatabase.eip55String

    lazy var rate: CurrencyRate = {
        CurrencyRate(
            currency: symbol,
            rates: [
                Rate(
                    code: symbol,
                    price: price_usd,
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
