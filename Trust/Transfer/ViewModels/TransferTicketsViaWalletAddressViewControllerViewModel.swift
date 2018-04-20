// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct TransferTicketsViaWalletAddressViewControllerViewModel {

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

    var zoneName: String {
        return ticketHolder.zone
    }

	var venue: String {
        return ticketHolder.venue
    }

    var date: String {
        //TODO Should format be localized?
        return ticketHolder.date.format("dd MMM yyyy")
    }
    var textFieldTextColor: UIColor {
        return Colors.appText
    }
    var textFieldFont: UIFont {
        if ScreenChecker().isNarrowScreen() {
            return Fonts.light(size: 11)!
        } else {
            return Fonts.light(size: 15)!
        }
    }
    var textFieldBorderColor: UIColor {
        return Colors.appBackground
    }
    var textFieldBorderWidth: CGFloat {
        return 1
    }
    var textFieldHorizontalPadding: CGFloat {
        return 22
    }
    var textFieldsLabelTextColor: UIColor {
        return UIColor(red: 155, green: 155, blue: 155)
    }
    var textFieldsLabelFont: UIFont {
        return Fonts.regular(size: 10)!
    }
}
