// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct SellTicketsQuantitySelectionViewModel {

    var ticketHolder: TicketHolder
    var ethCost: String = "0"

    var headerTitle: String {
		return R.string.localizable.aWalletTicketTokenSellSelectQuantityTitle()
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

    var subtitleLabelColor: UIColor {
        return UIColor(red: 155, green: 155, blue: 155)
    }

    var subtitleLabelFont: UIFont {
        return Fonts.light(size: 18)!
    }

    var subtitleLabelText: String {
        return R.string.localizable.aWalletTicketTokenSellEthHelpTitle()
    }

    var ethHelpButtonFont: UIFont {
        return Fonts.semibold(size: 18)!
    }

    var choiceLabelColor: UIColor {
        return UIColor(red: 155, green: 155, blue: 155)
    }

    var choiceLabelFont: UIFont {
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

    var zoneName: String {
        return ticketHolder.zone
    }

	var venue: String {
        return ticketHolder.venue
    }

    var quantityLabelText: String {
		return R.string.localizable.aWalletTicketTokenSellQuantityTitle()
    }

    var date: String {
        //TODO Should format be localized?
        return ticketHolder.date.format("dd MMM yyyy")
    }

    var pricePerTicketLabelText: String {
        return R.string.localizable.aWalletTicketTokenSellPricePerTicketTitle()
    }

    var linkExpiryDateLabelText: String {
        return R.string.localizable.aWalletTicketTokenSellLinkExpiryDateTitle()
    }

    var linkExpiryTimeLabelText: String {
        return R.string.localizable.aWalletTicketTokenSellLinkExpiryTimeTitle()
    }

    var totalCostLabelText: String {
        return R.string.localizable.aWalletTicketTokenSellTotalCostTitle()
    }

    var totalCostLabelFont: UIFont {
        return Fonts.light(size: 21)!
    }

    var totalCostLabelColor: UIColor {
        return Colors.appText
    }

    var costLabelText: String {
        return "\(ethCost) ETH"
    }

    var costLabelColor: UIColor {
        return Colors.appBackground
    }

    var costLabelFont: UIFont {
        return Fonts.semibold(size: 21)!
    }

    init(ticketHolder: TicketHolder) {
        self.ticketHolder = ticketHolder
    }
}
