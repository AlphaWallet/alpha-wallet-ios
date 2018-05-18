// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct GenerateTransferMagicLinkViewControllerViewModel {
    var ticketHolder: TicketHolder
    var linkExpiryDate: Date

    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }
    var subtitleColor: UIColor {
        return Colors.appText
    }
    var subtitleFont: UIFont {
        return Fonts.light(size: 25)!
    }
    var subtitleLabelText: String {
        return R.string.localizable.aWalletTicketTokenTransferConfirmSubtitle()
    }

	var headerTitle: String {
		return R.string.localizable.aWalletTicketTokenTransferConfirmTitle()
	}

    var actionButtonTitleColor: UIColor {
        return Colors.appWhite
    }
    var actionButtonBackgroundColor: UIColor {
        return Colors.appBackground
    }
    var actionButtonTitleFont: UIFont {
        return Fonts.regular(size: 20)!
    }
    var cancelButtonTitleColor: UIColor {
        return Colors.appRed
    }
    var cancelButtonBackgroundColor: UIColor {
        return .clear
    }
    var cancelButtonTitleFont: UIFont {
        return Fonts.regular(size: 20)!
    }
    var actionButtonTitle: String {
        return R.string.localizable.aWalletTicketTokenSellConfirmButtonTitle()
    }
    var cancelButtonTitle: String {
        return R.string.localizable.aWalletTicketTokenSellConfirmCancelButtonTitle()
    }

    var ticketSaleDetailsLabelFont: UIFont {
        return Fonts.semibold(size: 21)!
    }

    var ticketSaleDetailsLabelColor: UIColor {
        return Colors.appBackground
    }

    var descriptionLabelText: String {
        return R.string.localizable.aWalletTicketTokenSellConfirmExpiryDateDescription(linkExpiryDate.format("dd MMM yyyy  hh:mm"))
    }

    var ticketCountLabelText: String {
        if ticketCount == 1 {
            return R.string.localizable.aWalletTicketTokenSellConfirmSingleTicketSelectedTitle()
        } else {
            return R.string.localizable.aWalletTicketTokenSellConfirmMultipleTicketSelectedTitle(ticketHolder.count)
        }
    }

    var detailsBackgroundBackgroundColor: UIColor {
        return UIColor(red: 236, green: 236, blue: 236)
    }

    private var ticketCount: Int {
        return ticketHolder.count
    }

    init(ticketHolder: TicketHolder, linkExpiryDate: Date) {
        self.ticketHolder = ticketHolder
        self.linkExpiryDate = linkExpiryDate
    }
}
