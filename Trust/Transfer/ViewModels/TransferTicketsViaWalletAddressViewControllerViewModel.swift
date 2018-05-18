// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct TransferTicketsViaWalletAddressViewControllerViewModel {

    var token: TokenObject
    var ticketHolder: TicketHolder

    var headerTitle: String {
		return R.string.localizable.aWalletTicketTokenTransferSelectQuantityTitle()
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var buttonTitleColor: UIColor {
        return Colors.appWhite
    }

    var buttonBackgroundColor: UIColor {
        return Colors.appHighlightGreen
    }

    var buttonFont: UIFont {
        return Fonts.regular(size: 20)!
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
