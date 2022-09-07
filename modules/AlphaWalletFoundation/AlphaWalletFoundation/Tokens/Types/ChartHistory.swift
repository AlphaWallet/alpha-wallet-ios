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
    
    public var index: Int {
        switch self {
        case .day:
            return 0
        case .month:
            return 1
        case .threeMonth:
            return 2
        case .week:
            return 3
        case .year:
            return 4
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
    public static var empty: ChartHistory = .init(prices: [])

    public let prices: [HistoryValue]
}

extension ChartHistory: Codable, CustomDebugStringConvertible {
    private enum CodingKeys: String, CodingKey {
        case prices
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prices = try container.decode([HistoryValue].self, forKey: .prices)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(prices, forKey: .prices)
    }

    public var debugDescription: String {
        return "prices: \(prices.count)"
    }
}

extension ChartHistory {
    enum DecodingError: Error {
        case jsonDecodeFailure
    }

    init(json: JSON) throws {
        guard json["prices"].null == nil else { throw DecodingError.jsonDecodeFailure }

        prices = json["prices"].arrayValue.map { json -> HistoryValue in
            let timestamp = json.arrayValue[0].numberValue.doubleValue / 1000.0
            let value = json.arrayValue[1].numberValue.doubleValue

            return HistoryValue(timestamp: timestamp, value: value)
        }
    }
}
