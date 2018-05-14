// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct SetTransferTicketsExpiryDateViewControllerViewModel {

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

	var venue: String {
        return ticketHolder.venue
    }

    var date: String {
        return ticketHolder.date.format("dd MMM YYYY")
    }

    var descriptionLabelText: String {
        return R.string.localizable.aWalletTicketTokenTransferMagicLinkDescriptionTitle()
    }

    var descriptionLabelFont: UIFont {
        return Fonts.light(size: 21)!
    }

    var descriptionLabelColor: UIColor {
        return Colors.appText
    }
    
    var noteTitleLabelText: String {
        return R.string.localizable.aWalletTicketTokenSellNoteTitleLabelTitle()
    }

    var noteTitleLabelFont: UIFont {
        return Fonts.semibold(size: 21)!
    }

    var noteTitleLabelColor: UIColor {
        return Colors.appRed
    }

    var noteLabelText: String {
        return R.string.localizable.aWalletTicketTokenTransferNoteLabelTitle()
    }

    var noteLabelFont: UIFont {
        return Fonts.light(size: 21)!
    }

    var noteLabelColor: UIColor {
        return Colors.appRed
    }

    var noteBorderColor: UIColor {
        return Colors.appRed
    }
    
    var choiceLabelColor: UIColor {
        return Colors.appGrayLabelColor
    }

    var choiceLabelFont: UIFont {
        return Fonts.regular(size: 10)!
    }
    
    var linkExpiryDateLabelText: String {
        return R.string.localizable.aWalletTicketTokenSellLinkExpiryDateTitle()
    }

    var linkExpiryTimeLabelText: String {
        return R.string.localizable.aWalletTicketTokenSellLinkExpiryTimeTitle()
    }
}
