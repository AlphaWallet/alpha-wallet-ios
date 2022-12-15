//
//  ChartHistory.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2021.
//

import Foundation
import SwiftyJSON

public enum ChartHistoryPeriod: Int, CaseIterable, Codable {
    case day = 1
    case week = 7
    case month = 30
    case threeMonth = 90
    case year = 360

    public var title: String {
        switch self {
        case .day:
            return "1D"
        case .month:
            return "1M"
        case .threeMonth:
            return "3M"
        case .week:
            return "1W"
        case .year:
            return "1Y"
        }
    }

    public init?(index: Int) {
        switch index {
        case 0:
            self = .day
        case 1:
            self = .month
        case 2:
            self = .threeMonth
        case 3:
            self = .week
        case 4:
            self = .year
        default:
            return nil
        }
    }
}

public struct HistoryValue: Codable, Equatable {
    public let timestamp: TimeInterval
    public let value: Double
}

public struct MappedChartHistory: Codable {
    public let history: ChartHistory
    public let fetchDate: Date
}

public struct ChartHistory {
    public static func empty(currency: Currency) -> ChartHistory {
        return .init(prices: [], currency: currency)
    }

    public let prices: [HistoryValue]
    public let currency: Currency
}

extension ChartHistory: Codable, CustomDebugStringConvertible {
    private enum CodingKeys: String, CodingKey {
        case prices
        case currency
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prices = try container.decode([HistoryValue].self, forKey: .prices)
        currency = try container.decodeIfPresent(Currency.self, forKey: .currency) ?? .default
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(prices, forKey: .prices)
        try container.encode(currency, forKey: .currency)
    }

    public var debugDescription: String {
        return "prices: \(prices.count), currency: \(currency)"
    }
}

extension ChartHistory {
    enum DecodingError: Error {
        case jsonDecodeFailure
    }

    init(json: JSON, currency: Currency) throws {
        guard json["prices"].null == nil else { throw DecodingError.jsonDecodeFailure }
        
        self.currency = currency
        self.prices = json["prices"].arrayValue.map { json -> HistoryValue in
            let timestamp = json.arrayValue[0].numberValue.doubleValue / 1000.0
            let value = json.arrayValue[1].numberValue.doubleValue

            return HistoryValue(timestamp: timestamp, value: value)
        }
    }
}
