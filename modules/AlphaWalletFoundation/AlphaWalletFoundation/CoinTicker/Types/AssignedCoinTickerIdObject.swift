//
//  AssignedCoinTickerIdObject.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 05.09.2022.
//

import Foundation
import RealmSwift

class AssignedCoinTickerIdObject: Object {
    @objc dynamic var primaryKey: String = ""
    @objc dynamic var _chartHistory: Data?
    let tickers = List<CoinTickerObject>()

    var chartHistory: [ChartHistoryPeriod: [Currency: MappedChartHistory]]? {
        get {
            return _chartHistory.flatMap {
                if let histories = try? JSONDecoder().decode([ChartHistoryPeriod: MappedChartHistory].self, from: $0) {
                    return histories.mapValues { [$0.history.currency: $0] }
                } else if let history = try? JSONDecoder().decode([ChartHistoryPeriod: [Currency: MappedChartHistory]].self, from: $0) {
                    return history
                } else {
                    return nil
                }
            }
        }
        set { _chartHistory = try? JSONEncoder().encode(newValue) }
    }

    convenience init(tickerId: KnownTickerIdObject, tickers: [CoinTickerObject], chartHistories: [ChartHistoryPeriod: [Currency: MappedChartHistory]]?) {
        self.init()
        self.primaryKey = tickerId.primaryKey
        self._chartHistory = chartHistories.flatMap { try? JSONEncoder().encode($0) }
        self.tickers.append(objectsIn: tickers)
    }

    override static func primaryKey() -> String? {
        return "primaryKey"
    }

    override static func ignoredProperties() -> [String] {
        return ["ticker", "chartHistory"]
    }
}
