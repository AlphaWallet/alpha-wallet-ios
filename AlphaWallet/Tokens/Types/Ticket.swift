//
//  Ticket.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/25/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import BigInt

struct Ticket {
    let id: BigUInt
    let index: UInt16
    var name: String
    let values: [String: AssetAttributeValue]

    static var empty: Ticket {
        return Ticket(
                id: Constants.nullTicketBigUInt,
                index: 0,
                name: "FIFA WC",
                values: [
                    "locality": "N/A",
                    "venue": "N/A",
                    "match": 0,
                    "time": GeneralisedTime.init(),
                    "numero": 0,
                    "category": "N/A",
                    "countryA": "N/A",
                    "countryB": "N/A"
                ]
        )
    }
}
