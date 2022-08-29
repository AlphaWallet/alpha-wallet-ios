//
//  CoinTickerObject.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 05.09.2022.
//

import Foundation
import RealmSwift

class CoinTickerObject: Object {
    @objc dynamic var id: String = ""
    @objc dynamic var symbol: String = ""
    @objc dynamic var image: String = ""
    @objc dynamic var price_usd: Double = 0
    @objc dynamic var percent_change_24h: Double = 0
    var market_cap = RealmProperty<Double?>()
    var market_cap_rank = RealmProperty<Double?>()
    var total_volume = RealmProperty<Double?>()
    var high_24h = RealmProperty<Double?>()
    var low_24h = RealmProperty<Double?>()
    var market_cap_change_24h = RealmProperty<Double?>()
    var market_cap_change_percentage_24h = RealmProperty<Double?>()
    var circulating_supply = RealmProperty<Double?>()
    var total_supply = RealmProperty<Double?>()
    var max_supply = RealmProperty<Double?>()
    var ath = RealmProperty<Double?>()
    var ath_change_percentage = RealmProperty<Double?>()

    convenience init(coinTicker: CoinTicker) {
        self.init()
        self.id = coinTicker.id
        self.symbol = coinTicker.symbol
        self.image = coinTicker.image
        self.price_usd = coinTicker.price_usd
        self.percent_change_24h = coinTicker.percent_change_24h
        self.market_cap.value = coinTicker.market_cap
        self.market_cap_rank.value = coinTicker.market_cap_rank
        self.total_volume.value = coinTicker.total_volume
        self.high_24h.value = coinTicker.high_24h
        self.low_24h.value = coinTicker.low_24h
        self.market_cap_change_24h.value = coinTicker.market_cap_change_24h
        self.market_cap_change_percentage_24h.value = coinTicker.market_cap_change_percentage_24h
        self.circulating_supply.value = coinTicker.circulating_supply
        self.total_supply.value = coinTicker.total_supply
        self.max_supply.value = coinTicker.max_supply
        self.ath.value = coinTicker.ath
        self.ath_change_percentage.value = coinTicker.ath_change_percentage
    }

    override static func primaryKey() -> String? {
        return "id"
    }
}
