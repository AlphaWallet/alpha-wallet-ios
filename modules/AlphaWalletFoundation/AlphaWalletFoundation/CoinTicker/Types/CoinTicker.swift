// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public struct CoinTicker: Hashable, Equatable {
    public let primaryKey: String
    public let id: String
    public let currency: Currency
    public let lastUpdatedAt: Date
    public let symbol: String
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
}

extension CoinTicker {
    public static func make(for token: TokenMappedToTicker, currency: Currency) -> CoinTicker {
        let id = "for-testing-tickerId-\(token.contractAddress)-\(token.server.chainID)"
        return .init(primaryKey: "\(id)-\(currency.code)", id: id, currency: currency, lastUpdatedAt: Date(), symbol: "", price_usd: 0.0, percent_change_24h: 0.0, market_cap: 0.0, market_cap_rank: 0.0, total_volume: 0.0, high_24h: 0.0, low_24h: 0.0, market_cap_change_24h: 0.0, market_cap_change_percentage_24h: 0.0, circulating_supply: 0.0, total_supply: 0.0, max_supply: 0.0, ath: 0.0, ath_change_percentage: 0.0)
    }

    public func override(currency: Currency) -> CoinTicker {
        let primaryKey = "\(id)-\(currency)"
        return .init(primaryKey: primaryKey, id: id, currency: currency, lastUpdatedAt: lastUpdatedAt, symbol: symbol, price_usd: price_usd, percent_change_24h: percent_change_24h, market_cap: market_cap, market_cap_rank: market_cap_rank, total_volume: total_volume, high_24h: high_24h, low_24h: low_24h, market_cap_change_24h: market_cap_change_24h, market_cap_change_percentage_24h: market_cap_change_percentage_24h, circulating_supply: circulating_supply, total_supply: total_supply, max_supply: max_supply, ath: ath, ath_change_percentage: ath_change_percentage)
    }

    public func override(price_usd: Double) -> CoinTicker {
        return .init(primaryKey: primaryKey, id: id, currency: currency, lastUpdatedAt: lastUpdatedAt, symbol: symbol, price_usd: price_usd, percent_change_24h: percent_change_24h, market_cap: market_cap, market_cap_rank: market_cap_rank, total_volume: total_volume, high_24h: high_24h, low_24h: low_24h, market_cap_change_24h: market_cap_change_24h, market_cap_change_percentage_24h: market_cap_change_percentage_24h, circulating_supply: circulating_supply, total_supply: total_supply, max_supply: max_supply, ath: ath, ath_change_percentage: ath_change_percentage)
    }

    init(coinTickerObject: CoinTickerObject) {
        self.primaryKey = coinTickerObject.primaryKey
        self.id = coinTickerObject.id
        self.lastUpdatedAt = coinTickerObject.lastUpdatedAt
        self.currency = Currency(rawValue: coinTickerObject.currency) ?? .default
        self.symbol = coinTickerObject.symbol
        self.price_usd = coinTickerObject.price_usd
        self.percent_change_24h = coinTickerObject.percent_change_24h
        self.market_cap = coinTickerObject.market_cap.value
        self.market_cap_rank = coinTickerObject.market_cap_rank.value
        self.total_volume = coinTickerObject.total_volume.value
        self.high_24h = coinTickerObject.high_24h.value
        self.low_24h = coinTickerObject.low_24h.value
        self.market_cap_change_24h = coinTickerObject.market_cap_change_24h.value
        self.market_cap_change_percentage_24h = coinTickerObject.market_cap_change_percentage_24h.value
        self.circulating_supply = coinTickerObject.circulating_supply.value
        self.total_supply = coinTickerObject.total_supply.value
        self.max_supply = coinTickerObject.max_supply.value
        self.ath = coinTickerObject.ath.value
        self.ath_change_percentage = coinTickerObject.ath_change_percentage.value
    }
}

extension CoinTicker: Codable {
    private enum CodingKeys: String, CodingKey {
        case price_usd = "current_price"
        case percent_change_24h = "price_change_percentage_24h"
        case id = "id"
        case symbol = "symbol"
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

    public init(from decoder: Decoder) throws {
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
            throw CastError(actualValue: container, expectedType: String.self)
        }

        if let value = try? container.decode(String.self, forKey: .symbol) {
            self.symbol = value
        } else {
            throw CastError(actualValue: container, expectedType: String.self)
        }

        currency = .default
        self.primaryKey = "\(id)-\(currency)"
        lastUpdatedAt = Date()
    }

}

extension KeyedDecodingContainer where Key: Hashable {
    public func decode<T>(_ type: T.Type, forKey key: Key, defaultValue: T) -> T where T: Decodable {
        if let typedValueOptional = try? decodeIfPresent(T.self, forKey: key) {
            return typedValueOptional
        } else {
            return defaultValue
        }
    }

    public func decode<T>(_ type: T.Type, forKey key: Key, defaultValue: T?) -> T? where T: Decodable {
        if let typedValueOptional = try? decodeIfPresent(T.self, forKey: key) {
            return typedValueOptional
        } else {
            return defaultValue
        }
    }
}
