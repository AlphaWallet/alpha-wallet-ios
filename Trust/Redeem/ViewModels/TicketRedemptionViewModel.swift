//
//  TicketRedemptionViewModel.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/6/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit

struct TicketRedemptionViewModel {
    var token: TokenObject
    var ticketHolder: TicketHolder

    var headerTitle: String {
        return R.string.localizable.aWalletTicketTokenRedeemShowQRCodeTitle()
    }

    var headerColor: UIColor {
        return Colors.appWhite
    }

    var headerFont: UIFont {
        return Fonts.light(size: 25)!
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var ticketCount: String {
        return "x\(ticketHolder.tickets.count)"
    }

    var city: String {
        return ticketHolder.city
    }

    var category: String {
        return String(ticketHolder.category)
    }

    var teams: String {
        return R.string.localizable.aWalletTicketTokenMatchVs(ticketHolder.countryA, ticketHolder.countryB)
    }

    var match: String {
        return "M\(ticketHolder.match)"
    }

    var venue: String {
        return ticketHolder.venue
    }

    var date: String {
        return ticketHolder.date.formatAsShortDateString(overrideWithTimezoneIdentifier: ticketHolder.timeZoneIdentifier)
    }
}
