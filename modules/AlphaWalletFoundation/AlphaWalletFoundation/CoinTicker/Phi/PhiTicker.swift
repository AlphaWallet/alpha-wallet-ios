//
//  PhiTicker.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 16.09.2022.
//

import SwiftyJSON
import AlphaWalletCore

struct PhiTicker {
    let id: String
    let symbol: String
    let price: Double
    let total_liquidity: String
    let price_change_24h: Double
    let percent_change_24h: String
    let total_transactions_24h: Double
    let total_volume_24h: Double
    let volume_change_24h: Double
    let percent_volume_change_24h: String
    let currency: String
}

extension PhiTicker {
    enum PhiTickerDecodeError: Error {}

    init?(json: JSON, tickerId: String, currency: String) {
        guard let id = json["data"][tickerId]["id"].string else { return nil }
        self.id = id
        self.currency = currency
        symbol = json["data"][tickerId]["symbol"].stringValue
        let fiatQuote = json["data"]["quotes"][currency]
        price = fiatQuote["price"].doubleValue
        total_liquidity = fiatQuote["total_liquidity"].stringValue
        price_change_24h = fiatQuote["price_change_24h"].doubleValue
        percent_change_24h = fiatQuote["percent_change_24h"].stringValue
        total_transactions_24h = fiatQuote["total_transactions_24h"].doubleValue
        total_volume_24h = fiatQuote["total_volume_24h"].doubleValue
        volume_change_24h = fiatQuote["volume_change_24h"].doubleValue
        percent_volume_change_24h = fiatQuote["percent_volume_change_24h"].stringValue
    }
}

extension CoinTicker {
    
    init(phiTicker: PhiTicker, id: String) {
        self.id = id
        self.symbol = phiTicker.symbol
        self.image = ""
        self.price_usd = phiTicker.price
        self.percent_change_24h = phiTicker.price_change_24h
        self.market_cap = phiTicker.total_liquidity.optionalDecimalValue?.doubleValue
        self.market_cap_rank = nil
        self.total_volume = nil
        self.high_24h = nil
        self.low_24h = nil
        self.market_cap_change_24h = nil
        self.market_cap_change_percentage_24h = nil
        self.circulating_supply = nil
        self.total_supply = nil
        self.max_supply = nil
        self.ath = nil
        self.ath_change_percentage = nil
        self.currency = phiTicker.currency
    }
}
