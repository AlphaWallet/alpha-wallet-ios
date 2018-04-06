// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct TransferTicketViaWalletAddressViewControllerViewModel {
    var ticketHolder: TicketHolder

    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }
    var titleColor: UIColor {
        return Colors.appText
    }
    var titleFont: UIFont {
        return Fonts.light(size: 25)!
    }
    var subtitleColor: UIColor {
        return UIColor(red: 155, green: 155, blue: 155)
    }
    var subtitleFont: UIFont {
        return Fonts.regular(size: 10)!
    }
    var actionButtonTitleColor: UIColor {
        return Colors.appWhite
    }
    var actionButtonBackgroundColor: UIColor {
        return Colors.appHighlightGreen
    }
    var actionButtonTitleFont: UIFont {
        return Fonts.regular(size: 20)!
    }
    var titleLabelText: String {
        return R.string.localizable.aWalletTicketTokenTransferModeWalletAddressTitle()
    }
    var subtitleLabelText: String {
        return R.string.localizable.aWalletTicketTokenTransferModeWalletAddressTargetTitle()
    }
    var actionButtonTitle: String {
        return R.string.localizable.aWalletTicketTokenTransferButtonTitle()
    }
    var textFieldTextColor: UIColor {
        return Colors.appText
    }
    var textFieldFont: UIFont {
        return Fonts.light(size: 15)!
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
}
