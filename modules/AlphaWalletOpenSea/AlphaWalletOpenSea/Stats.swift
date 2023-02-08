//
//  Stats.swift
//  AlphaWalletOpenSea
//
//  Created by Vladyslav Shepitko on 31.01.2022.
//

import Foundation
import SwiftyJSON

public struct NftCollectionStats: Codable {
    public let oneDayVolume: Double
    public let oneDayChange: Double
    public let oneDaySales: Double
    public let oneDayAveragePrice: Double
    public let sevenDayVolume: Double
    public let sevenDayChange: Double
    public let sevenDaySales: Double
    public let sevenDayAveragePrice: Double

    public let thirtyDayVolume: Double
    public let thirtyDayChange: Double
    public let thirtyDaySales: Double
    public let thirtyDayAveragePrice: Double

    public let itemsCount: Double
    public let totalVolume: Double
    public let totalSales: Double
    public let totalSupply: Double

    public let owners: Int
    public let averagePrice: Double
    public let marketCap: Double
    public let floorPrice: Double?
    public let numReports: Int

    init(json: JSON) {
        oneDayVolume = json["one_day_volume"].doubleValue
        oneDayChange = json["one_day_change"].doubleValue
        oneDaySales = json["one_day_sales"].doubleValue
        oneDayAveragePrice = json["one_day_average_price"].doubleValue
        sevenDayVolume = json["seven_day_volume"].doubleValue
        sevenDayChange = json["seven_day_change"].doubleValue
        sevenDaySales = json["seven_day_sales"].doubleValue
        sevenDayAveragePrice = json["seven_day_average_price"].doubleValue
        thirtyDayVolume = json["thirty_day_volume"].doubleValue
        thirtyDayChange = json["thirty_day_change"].doubleValue
        thirtyDaySales = json["thirty_day_sales"].doubleValue
        thirtyDayAveragePrice = json["thirty_day_average_price"].doubleValue
        itemsCount = json["count"].doubleValue
        totalVolume = json["total_volume"].doubleValue
        totalSales = json["total_sales"].doubleValue
        totalSupply = json["total_supply"].doubleValue
        owners = json["num_owners"].intValue
        averagePrice = json["average_price"].doubleValue
        marketCap = json["market_cap"].doubleValue
        floorPrice = json["floor_price"].double
        numReports = json["num_reports"].intValue
    }
}
