//
//  ChartHistory.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2021.
//

import UIKit

enum ChartHistoryPeriod: Int, CaseIterable, Codable {
    case day = 1
    case week = 7
    case month = 30
    case threeMonth = 90
    case year = 360

    var title: String {
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
    
    var index: Int {
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

struct HistoryValue: Codable, Equatable {
    let timestamp: TimeInterval
    let value: Double
}

struct MappedChartHistory: Codable {
    let history: ChartHistory
    let fetchDate: Date
}

struct ChartHistory: Codable, CustomDebugStringConvertible {

    private enum CodingKeys: String, CodingKey {
        case prices
    }

    let prices: [HistoryValue]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        prices = container.decode([[Double]].self, forKey: .prices, defaultValue: []).map { value -> HistoryValue in
            return .init(timestamp: value[0] / 1000.0, value: value[1])
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(prices, forKey: .prices)
    }

    init(prices: [HistoryValue]) {
        self.prices = prices
    }

    static var empty: ChartHistory = .init(prices: [])

    var debugDescription: String {
        return "prices: \(prices.count)"
    }
}
