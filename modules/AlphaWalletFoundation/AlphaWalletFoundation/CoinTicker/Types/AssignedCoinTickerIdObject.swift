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
    @objc dynamic var _ticker: CoinTickerObject?
    @objc dynamic var _chartHistory: Data?
    @objc dynamic var historyUpdatedAt = NSDate()

    var chartHistory: [ChartHistoryPeriod: MappedChartHistory]? {
        get { return _chartHistory.flatMap { try? JSONDecoder().decode([ChartHistoryPeriod: MappedChartHistory].self, from: $0) } }
        set { _chartHistory = try? JSONEncoder().encode(newValue) }
    }

    var ticker: CoinTickerObject? {
        get { return _ticker }
        set { _ticker = newValue }
    }

    convenience init(tickerId: KnownTickerIdObject, ticker: CoinTickerObject?, chartHistory: [ChartHistoryPeriod: MappedChartHistory]?) {
        self.init()
        self.primaryKey = tickerId.primaryKey
        self._chartHistory = chartHistory.flatMap { try? JSONEncoder().encode($0) }
        self._ticker = ticker
        self.historyUpdatedAt = NSDate()
    }

    override static func primaryKey() -> String? {
        return "primaryKey"
    }

    override static func ignoredProperties() -> [String] {
        return ["ticker", "chartHistory"]
    }
}
