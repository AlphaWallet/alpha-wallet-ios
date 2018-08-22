// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct ChooseTokenTransferModeViewControllerViewModel {

    var token: TokenObject
    var TokenHolder: TokenHolder

    var headerTitle: String {
		return R.string.localizable.aWalletTokenTokenTransferSelectQuantityTitle()
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
