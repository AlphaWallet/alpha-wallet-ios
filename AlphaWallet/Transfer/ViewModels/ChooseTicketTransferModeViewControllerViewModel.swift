// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct ChooseTicketTransferModeViewControllerViewModel {

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
        if ScreenChecker().isNarrowScreen() {
            return Fonts.regular(size: 13)!
        } else {
            return Fonts.regular(size: 16)!
        }
    }
}
