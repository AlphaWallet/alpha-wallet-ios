//
//  OpenSeaStats.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 31.01.2022.
//

import Foundation
import SwiftyJSON

extension OpenSea {

    struct Stats: Codable {
        let oneDayVolume: Double
        let oneDayChange: Double
        let oneDaySales: Double
        let oneDayAveragePrice: Double
        let sevenDayVolume: Double
        let sevenDayChange: Double
        let sevenDaySales: Double
        let sevenDayAveragePrice: Double

        let thirtyDayVolume: Double
        let thirtyDayChange: Double
        let thirtyDaySales: Double
        let thirtyDayAveragePrice: Double

        let itemsCount: Double
        let totalVolume: Double
        let totalSales: Double
        let totalSupply: Double

        let owners: Int
        let averagePrice: Double
        let marketCap: Double
        let floorPrice: Double?
        let numReports: Int

        init(json: JSON) throws {
            guard json["stats"] != .null else {
                throw OpenSeaAssetDecoder.DecoderError.statsDecoding
            }
            let json = json["stats"]

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
}
