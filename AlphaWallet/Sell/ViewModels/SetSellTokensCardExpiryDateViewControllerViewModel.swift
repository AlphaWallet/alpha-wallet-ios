// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct SetSellTokensCardExpiryDateViewControllerViewModel {
    private let ethCost: Ether

    let token: TokenObject
    let tokenHolder: TokenHolder

    var headerTitle: String {
		return R.string.localizable.aWalletTokenSellEnterLinkExpiryDateTitle()
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
        return R.string.localizable.aWalletTokenSellLinkExpiryDateTitle()
    }

    var linkExpiryTimeLabelText: String {
        return R.string.localizable.aWalletTokenSellLinkExpiryTimeTitle()
    }

    var tokenSaleDetailsLabelFont: UIFont {
        return Fonts.semibold(size: 21)!
    }

    var tokenSaleDetailsLabelColor: UIColor {
        return Colors.appBackground
    }

    var descriptionLabelText: String {
        let tokenTypeName = XMLHandler(contract: token.contract).getTokenTypeName(.plural, titlecase: .notTitlecase)
        return R.string.localizable.aWalletTokenSellMagicLinkDescriptionTitle(tokenTypeName)
    }

    var descriptionLabelFont: UIFont {
        return Fonts.light(size: 21)!
    }

    var descriptionLabelColor: UIColor {
        return Colors.appText
    }

    var tokenCountLabelText: String {
        if tokenCount == 1 {
            let tokenTypeName = XMLHandler(contract: token.address.eip55String).getTokenTypeName(.singular, titlecase: .titlecase)
            return R.string.localizable.aWalletTokenSellSingleTokenSelectedTitle(tokenTypeName)
        } else {
            let tokenTypeName = XMLHandler(contract: token.address.eip55String).getTokenTypeName(.plural, titlecase: .titlecase)
            return R.string.localizable.aWalletTokenSellMultipleTokenSelectedTitle(tokenHolder.count, tokenTypeName)
        }
    }

    var perTokenPriceLabelText: String {
        let tokenTypeName = XMLHandler(contract: token.contract).getTokenTypeName(.singular, titlecase: .titlecase)
        let amount = ethCost / tokenCount
        return R.string.localizable.aWalletTokenSellPerTokenEthPriceTitle(amount.formattedDescription, tokenTypeName)
    }

    var totalEthLabelText: String {
        return R.string.localizable.aWalletTokenSellTotalEthPriceTitle(ethCost.formattedDescription)
    }

    var noteTitleLabelText: String {
        return R.string.localizable.aWalletTokenSellNoteTitleLabelTitle()
    }

    var noteTitleLabelFont: UIFont {
        return Fonts.semibold(size: 21)!
    }

    var noteTitleLabelColor: UIColor {
        return Colors.appRed
    }

    var noteLabelText: String {
        let tokenTypeName = XMLHandler(contract: token.contract).getTokenTypeName(.plural, titlecase: .notTitlecase)
        return R.string.localizable.aWalletTokenSellNoteLabelTitle(tokenTypeName)
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

    private var tokenCount: Int {
        return tokenHolder.count
    }

    init(token: TokenObject, tokenHolder: TokenHolder, ethCost: Ether) {
        self.token = token
        self.tokenHolder = tokenHolder
        self.ethCost = ethCost
    }
}
