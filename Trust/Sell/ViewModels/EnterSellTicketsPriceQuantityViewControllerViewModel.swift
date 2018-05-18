// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct EnterSellTicketsPriceQuantityViewControllerViewModel {

    var token: TokenObject
    var ticketHolder: TicketHolder
    var ethCost: String = "0"
    var dollarCost: String = ""

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

    var choiceLabelColor: UIColor {
        return Colors.appGrayLabelColor
    }

    var choiceLabelFont: UIFont {
        return Fonts.regular(size: 10)!
    }

    var stepperBorderColor: UIColor {
        return Colors.appBackground
    }

    var quantityLabelText: String {
		return R.string.localizable.aWalletTicketTokenSellQuantityTitle()
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

    var ethCostLabelLabelText: String {
        return R.string.localizable.aWalletTicketTokenSellTotalCostTitle()
    }

    var ethCostLabelLabelFont: UIFont {
        return Fonts.light(size: 21)!
    }

    var ethCostLabelLabelColor: UIColor {
        return Colors.appText
    }

    var ethCostLabelText: String {
        return "\(ethCost) ETH"
    }

    var ethCostLabelColor: UIColor {
        return Colors.appBackground
    }

    var ethCostLabelFont: UIFont {
        return Fonts.semibold(size: 21)!
    }

    var dollarCostLabelLabelColor: UIColor {
        return Colors.appGrayLabelColor
    }

    var dollarCostLabelLabelFont: UIFont {
        return Fonts.regular(size: 10)!
    }

    var dollarCostLabelText: String {
        return "$\(dollarCost)"
    }

    var dollarCostLabelColor: UIColor {
        return Colors.darkGray
    }

    var dollarCostLabelFont: UIFont {
        return Fonts.light(size: 21)!
    }

    var dollarCostLabelBackgroundColor: UIColor {
        return UIColor(red: 236, green: 236, blue: 236)
    }

    var hideDollarCost: Bool {
        return dollarCost.trimmed.isEmpty
    }

    init(token: TokenObject, ticketHolder: TicketHolder) {
        self.token = token
        self.ticketHolder = ticketHolder
    }
}
