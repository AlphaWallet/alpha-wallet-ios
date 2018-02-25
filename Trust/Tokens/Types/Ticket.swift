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
    let id: Int16
    let index: Int
    let zone: String
    let name: String
    let venue: String
    let date: Date
    let seatId: Int
}
