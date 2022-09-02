// Copyright SIX DAY LLC. All rights reserved.

import Foundation 

public struct CoinTicker: Hashable {
    public let id: String
    public let symbol: String
    public let image: String = ""
    public let price_usd: Double
    public let percent_change_24h: Double
    public let market_cap: Double?
    public let market_cap_rank: Double?
    public let total_volume: Double?
    public let high_24h: Double?
    public let low_24h: Double?
    public let market_cap_change_24h: Double?
    public let market_cap_change_percentage_24h: Double?
    public let circulating_supply: Double?
    public let total_supply: Double?
    public let max_supply: Double?
    public let ath: Double?
    public let ath_change_percentage: Double?

    public var rate: CurrencyRate {
        CurrencyRate(currency: symbol, rates: [Rate(code: symbol, price: price_usd)])
    }
}

extension CoinTicker {
    public static func make(for token: TokenMappedToTicker) -> CoinTicker {
        let id = "tickerId-\(token.contractAddress)-\(token.server.chainID)"
        return .init(id: id, symbol: "", price_usd: 0.0, percent_change_24h: 0.0, market_cap: 0.0, market_cap_rank: 0.0, total_volume: 0.0, high_24h: 0.0, low_24h: 0.0, market_cap_change_24h: 0.0, market_cap_change_percentage_24h: 0.0, circulating_supply: 0.0, total_supply: 0.0, max_supply: 0.0, ath: 0.0, ath_change_percentage: 0.0)
    }

    public func override(price_usd: Double) -> CoinTicker {
        return .init(id: id, symbol: symbol, price_usd: price_usd, percent_change_24h: percent_change_24h, market_cap: market_cap, market_cap_rank: market_cap_rank, total_volume: total_volume, high_24h: high_24h, low_24h: low_24h, market_cap_change_24h: market_cap_change_24h, market_cap_change_percentage_24h: market_cap_change_percentage_24h, circulating_supply: circulating_supply, total_supply: total_supply, max_supply: max_supply, ath: ath, ath_change_percentage: ath_change_percentage)
    }
}

extension CoinTicker: Codable {
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

    var imageURL: URL? {
        return URL(string: image)
    }

    public init(from decoder: Decoder) throws {
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

extension KeyedDecodingContainer where Key: Hashable {
    public func decode<T>(_ type: T.Type, forKey key: Key, defaultValue: T) -> T where T: Decodable {
        if let typedValueOptional = try? decodeIfPresent(T.self, forKey: key), let typedValue = typedValueOptional {
            return typedValue
        } else {
            return defaultValue
        }
    }

    public func decode<T>(_ type: T.Type, forKey key: Key, defaultValue: T?) -> T? where T: Decodable {
        if let typedValueOptional = try? decodeIfPresent(T.self, forKey: key), let typedValue = typedValueOptional {
            return typedValue
        } else {
            return defaultValue
        }
    }
}
