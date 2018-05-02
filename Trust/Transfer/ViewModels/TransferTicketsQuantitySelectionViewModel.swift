// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct TransferTicketsQuantitySelectionViewModel {

    var ticketHolder: TicketHolder

    var headerTitle: String {
		return R.string.localizable.aWalletTicketTokenTransferSelectQuantityTitle()
    }

    var maxValue: Int {
        return ticketHolder.tickets.count
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

    var subtitleColor: UIColor {
        return Colors.appGrayLabelColor
    }

    var subtitleFont: UIFont {
        return Fonts.regular(size: 10)!
    }

    var stepperBorderColor: UIColor {
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

    var category: String {
        return String(ticketHolder.category)
    }

	var venue: String {
        return ticketHolder.venue
    }

    var subtitleText: String {
		return R.string.localizable.aWalletTicketTokenTransferQuantityTitle()
    }

    var date: String {
        return ticketHolder.date.formatAsShortDateString()
    }
}
