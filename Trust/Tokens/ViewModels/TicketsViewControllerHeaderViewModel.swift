// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import BigInt

struct TicketsViewControllerHeaderViewModel {
    let config: Config
    private let tokenObject: TokenObject

    init(config: Config, tokenObject: TokenObject) {
        self.config = config
        self.tokenObject = tokenObject
    }

    var title: String {
        return "\((totalValidTicketNumber)) \(tokenObject.title)"
    }

    var issuer: String {
        if config.server == .main {
            return "\(R.string.localizable.aWalletContentsIssuerTitle()): \(R.string.localizable.ticketIssuer())"
        } else {
            return ""
        }
    }

    var issuerSeparator: String {
        if issuer.isEmpty {
            return ""
        } else {
            return "|"
        }
    }

    var blockChainName: String {
        return R.string.localizable.blockchainEthereum()
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var titleColor: UIColor {
        return Colors.appText
    }

    var subtitleColor: UIColor {
        return Colors.appBackground
    }

    var titleFont: UIFont {
        return Fonts.light(size: 25)!
    }

    var subtitleFont: UIFont {
        return Fonts.semibold(size: 10)!
    }

    var totalValidTicketNumber: String {
        let balance = tokenObject.balance
        let validTickets = balance.filter { $0.balance != Constants.nullTicket }
        return validTickets.count.toString()
    }
}
