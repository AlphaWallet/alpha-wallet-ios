// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct TransferTokensQuantitySelectionViewModel {

    var token: TokenObject
    var TokenHolder: TokenHolder

    var headerTitle: String {
		return R.string.localizable.aWalletTokenTokenTransferSelectQuantityTitle()
    }

    var maxValue: Int {
        return TokenHolder.Tokens.count
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

    var subtitleText: String {
		return R.string.localizable.aWalletTokenTokenTransferQuantityTitle()
    }
}
