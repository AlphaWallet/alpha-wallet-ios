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
}

struct MappedChartHistory: Codable {
    let history: ChartHistory
    let fetchDate: Date
}

struct ChartHistory: Codable, CustomDebugStringConvertible {

    private enum CodingKeys: String, CodingKey {
        case prices
    }

    let prices: [[Double]]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        prices = container.decode([[Double]].self, forKey: .prices, defaultValue: [])
    }

    init(prices: [[Double]]) {
        self.prices = prices
    }

    static var empty: ChartHistory = .init(prices: [])

    var debugDescription: String {
        return "prices: \(prices.count)"
    }
}
