// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct SetSellTokensExpiryDateViewControllerViewModel {

    var token: TokenObject
    var TokenHolder: TokenHolder
    var ethCost: String = "0"

    var headerTitle: String {
		return R.string.localizable.aWalletTokenTokenSellEnterLinkExpiryDateTitle()
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

    var linkExpiryDateLabelText: String {
        return R.string.localizable.aWalletTokenTokenSellLinkExpiryDateTitle()
    }

    var linkExpiryTimeLabelText: String {
        return R.string.localizable.aWalletTokenTokenSellLinkExpiryTimeTitle()
    }

    var TokenSaleDetailsLabelFont: UIFont {
        return Fonts.semibold(size: 21)!
    }

    var TokenSaleDetailsLabelColor: UIColor {
        return Colors.appBackground
    }

    var descriptionLabelText: String {
        return R.string.localizable.aWalletTokenTokenSellMagicLinkDescriptionTitle()
    }

    var descriptionLabelFont: UIFont {
        return Fonts.light(size: 21)!
    }

    var descriptionLabelColor: UIColor {
        return Colors.appText
    }

    var TokenCountLabelText: String {
        if TokenCount == 1 {
            return R.string.localizable.aWalletTokenTokenSellSingleTokenSelectedTitle()
        } else {
            return R.string.localizable.aWalletTokenTokenSellMultipleTokenSelectedTitle(TokenHolder.count)
        }
    }

    var perTokenPriceLabelText: String {
        let amount = Double(ethCost)! / Double(TokenCount)
        return R.string.localizable.aWalletTokenTokenSellPerTokenEthPriceTitle(amount)
    }

    var totalEthLabelText: String {
        return R.string.localizable.aWalletTokenTokenSellTotalEthPriceTitle(ethCost)
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
        return R.string.localizable.aWalletTokenTokenSellNoteLabelTitle()
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

    private var TokenCount: Int {
        return TokenHolder.count
    }

    init(token: TokenObject, TokenHolder: TokenHolder, ethCost: String) {
        self.token = token
        self.TokenHolder = TokenHolder
        self.ethCost = ethCost
    }
}
