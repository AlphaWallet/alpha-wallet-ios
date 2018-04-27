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

    var title: String {
        return ticketHolder.name
    }

    var seatRange: String {
        return ticketHolder.seatRange
    }

    var city: String {
        return ticketHolder.city
    }

    var venue: String {
        return ticketHolder.venue
    }

    var date: String {
        //TODO Should format be localized?
        return ticketHolder.date.format("dd MMM yyyy")
    }
}
