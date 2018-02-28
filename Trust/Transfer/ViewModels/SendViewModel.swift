// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import TrustKeystore

struct SendViewModel {

    let transferType: TransferType
    let config: Config
    let ticketHolders: [TicketHolder]!

    var title: String {
        return isStormBird ? "Transfer Ticket" : "Send" + symbol
    }

    var formHeaderTitle: String {
        if let ticketHolder = ticketHolders.first {
            return ticketHolder.name
        }
        return ""
    }

    var ticketNumbers: String {
        let tickets = ticketHolders.flatMap { $0.tickets }
        let ids = tickets.map { String($0.id) }
        return ids.joined(separator: ",")
    }

    var symbol: String {
        return transferType.symbol(server: config.server)
    }

    var destinationAddress: Address {
        return transferType.contract()
    }

    var backgroundColor: UIColor {
        return .white
    }

    var isStormBird: Bool {
        if let token = self.token {
            return token.isStormBird
        }
        return false
    }

    var token: TokenObject? {
        switch transferType {
        case .ether(destination: _):
            return nil
        case .token(let token):
            return token
        case .stormBird(let token):
            return token
        }
    }

}
