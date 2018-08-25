//
//  TokenHolder.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/25/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation

class TokenHolder {
    enum Status {
        case available, sold, redeemed, forSale, transferred
    }

    var tickets: [Token]
    var name: String { return tickets[0].name }
    var values: [String: AssetAttributeValue] { return tickets[0].values }
    var status: Status
    var isSelected = false
    var areDetailsVisible = false
    var contractAddress: String

    init(tickets: [Token], status: Status, contractAddress: String) {
        self.tickets = tickets
        self.status = status
        self.contractAddress = contractAddress
    }

    var count: Int {
        return tickets.count
    }

    var indices: [UInt16] {
        return tickets.map { $0.index }
    }
}
