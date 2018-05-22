//
//  Event.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/11/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation

struct Event: Codable {
    var address: String
    var blockNumber: Int
    var transactionHash: String
    var transactionIndex: Int
    var blockHash: String
    var logIndex: Int
    var removed: Bool
    var event: String
    var arguments: Arguments

    static func from(data: Data) -> [Event]? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? JSONDecoder().decode([Event].self, from: data)
    }
    
    static func from(data: Data) -> Event? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Event.self, from: data)
    }

    enum CodingKeys: String, CodingKey {
        case address
        case blockNumber
        case transactionHash
        case transactionIndex
        case blockHash
        case logIndex
        case event
        case removed
        case arguments = "args"
    }

}
