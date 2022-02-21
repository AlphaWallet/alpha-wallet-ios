// Copyright SIX DAY LLC. All rights reserved.

import Foundation 

struct CoinTicker: Codable, Hashable {
    private enum CodingKeys: String, CodingKey {
        case price_usd = "current_price"
        case percent_change_24h = "price_change_percentage_24h"
        case id = "id"
        case symbol = "symbol"
        case image = "image"
        case market_cap
        case market_cap_rank
        case total_volume
        case high_24h
        case low_24h
        case market_cap_change_24h
        case market_cap_change_percentage_24h
        case circulating_supply
        case total_supply
        case max_supply
        case ath
        case ath_change_percentage
    }

    let id: String
    let symbol: String
    let image: String = ""

    let price_usd: Double
    let percent_change_24h: Double

    let market_cap: Double?
    let market_cap_rank: Double?
    let total_volume: Double?
    let high_24h: Double?
    let low_24h: Double?
    let market_cap_change_24h: Double?
    let market_cap_change_percentage_24h: Double?
    let circulating_supply: Double?
    let total_supply: Double?
    let max_supply: Double?
    let ath: Double?
    let ath_change_percentage: Double?

    var rate: CurrencyRate {
        CurrencyRate(
            currency: symbol,
            rates: [
                Rate(code: symbol, price: price_usd),
            ]
        )
    }

    init(from decoder: Decoder) throws {
        enum AnyError: Error {
            case invalid
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.price_usd = container.decode(Double.self, forKey: .price_usd, defaultValue: 0.0)
        self.percent_change_24h = container.decode(Double.self, forKey: .percent_change_24h, defaultValue: 0.0)
        self.market_cap = container.decode(Double.self, forKey: .market_cap, defaultValue: nil)
        self.market_cap_rank = container.decode(Double.self, forKey: .market_cap_rank, defaultValue: nil)
        self.total_volume = container.decode(Double.self, forKey: .total_volume, defaultValue: nil)
        self.high_24h = container.decode(Double.self, forKey: .high_24h, defaultValue: nil)
        self.low_24h = container.decode(Double.self, forKey: .low_24h, defaultValue: nil)
        self.market_cap_change_24h = container.decode(Double.self, forKey: .market_cap_change_24h, defaultValue: nil)
        self.market_cap_change_percentage_24h = container.decode(Double.self, forKey: .market_cap_change_percentage_24h, defaultValue: nil)
        self.circulating_supply = container.decode(Double.self, forKey: .circulating_supply, defaultValue: nil)
        self.total_supply = container.decode(Double.self, forKey: .total_supply, defaultValue: nil)
        self.max_supply = container.decode(Double.self, forKey: .max_supply, defaultValue: nil)
        self.ath = container.decode(Double.self, forKey: .ath, defaultValue: nil)
        self.ath_change_percentage = container.decode(Double.self, forKey: .ath_change_percentage, defaultValue: nil)

        if let value = try? container.decode(String.self, forKey: .id) {
            self.id = value
        } else {
            throw AnyError.invalid
        }

        if let value = try? container.decode(String.self, forKey: .symbol) {
            self.symbol = value
        } else {
            throw AnyError.invalid
        }
    }
}

extension CoinTicker {
    var imageURL: URL? {
        return URL(string: image)
    }
}

extension KeyedDecodingContainer where Key: Hashable {
    func decode<T>(_ type: T.Type, forKey key: Key, defaultValue: T) -> T where T: Decodable {
        if let typedValueOptional = try? decodeIfPresent(T.self, forKey: key), let typedValue = typedValueOptional {
            return typedValue
        } else {
            return defaultValue
        }
    }

    func decode<T>(_ type: T.Type, forKey key: Key, defaultValue: T?) -> T? where T: Decodable {
        if let typedValueOptional = try? decodeIfPresent(T.self, forKey: key), let typedValue = typedValueOptional {
            return typedValue
        } else {
            return defaultValue
        }
    }
}
