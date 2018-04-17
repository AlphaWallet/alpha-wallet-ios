// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import BigInt

struct TicketsViewControllerHeaderViewModel {
    private let tokenObject: TokenObject

    init(tokenObject: TokenObject) {
        self.tokenObject = tokenObject
    }

    var title: String {
        return "\((totalValidTicketNumber)) \(tokenObject.title)"
    }

    var issuer: String {
        return "\(R.string.localizable.aWalletContentsIssuerTitle()): Shengkai"
    }

    var blockChainName: String {
        return "Ethereum Blockchain"
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
        let validTickets = balance.filter { $0.balance != "0" }
        return validTickets.count.toString()
    }
}
