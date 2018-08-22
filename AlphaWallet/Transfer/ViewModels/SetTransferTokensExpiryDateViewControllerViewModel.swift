// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct SetTransferTokensExpiryDateViewControllerViewModel {

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
        return Fonts.regular(size: 20)!
    }

    var descriptionLabelText: String {
        return R.string.localizable.aWalletTokenTokenTransferMagicLinkDescriptionTitle()
    }

    var descriptionLabelFont: UIFont {
        return Fonts.light(size: 21)!
    }

    var descriptionLabelColor: UIColor {
        return Colors.appText
    }
    
    var noteTitleLabelText: String {
        return R.string.localizable.aWalletTokenTokenSellNoteTitleLabelTitle()
    }

    var noteTitleLabelFont: UIFont {
        return Fonts.semibold(size: 21)!
    }

    var noteTitleLabelColor: UIColor {
        return Colors.appRed
    }

    var noteLabelText: String {
        return R.string.localizable.aWalletTokenTokenTransferNoteLabelTitle()
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
        return R.string.localizable.aWalletTokenTokenSellLinkExpiryDateTitle()
    }

    var linkExpiryTimeLabelText: String {
        return R.string.localizable.aWalletTokenTokenSellLinkExpiryTimeTitle()
    }
}
