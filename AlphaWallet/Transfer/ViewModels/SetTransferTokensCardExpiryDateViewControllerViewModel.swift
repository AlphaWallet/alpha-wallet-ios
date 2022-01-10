// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct SetTransferTokensCardExpiryDateViewControllerViewModel {
    let token: TokenObject
    let tokenHolder: TokenHolder
    let assetDefinitionStore: AssetDefinitionStore

    var headerTitle: String {
        let tokenTypeName = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
		return R.string.localizable.aWalletTokenTransferSelectQuantityTitle(tokenTypeName)
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var descriptionLabelText: String {
        return R.string.localizable.aWalletTokenTransferMagicLinkDescriptionTitle(preferredLanguages: Languages.preferred())
    }

    var descriptionLabelFont: UIFont {
        return Fonts.light(size: 21)
    }

    var descriptionLabelColor: UIColor {
        return Colors.appText
    }

    var noteTitleLabelText: String {
        return R.string.localizable.aWalletTokenSellNoteTitleLabelTitle(preferredLanguages: Languages.preferred())
    }

    var noteTitleLabelFont: UIFont {
        return Fonts.semibold(size: 21)
    }

    var noteTitleLabelColor: UIColor {
        return Colors.appRed
    }

    var noteLabelText: String {
        return R.string.localizable.aWalletTokenTransferNoteLabelTitle(preferredLanguages: Languages.preferred())
    }

    var noteLabelFont: UIFont {
        return Fonts.light(size: 21)
    }

    var noteLabelColor: UIColor {
        return Colors.appRed
    }

    var noteBorderColor: UIColor {
        return Colors.appRed
    }

    var noteCornerRadius: CGFloat {
        return Metrics.CornerRadius.box
    }

    var choiceLabelColor: UIColor {
        return Colors.appGrayLabel
    }

    var choiceLabelFont: UIFont {
        return Fonts.regular(size: 10)
    }

    var linkExpiryDateLabelText: String {
        return R.string.localizable.aWalletTokenSellLinkExpiryDateTitle(preferredLanguages: Languages.preferred())
    }

    var linkExpiryTimeLabelText: String {
        return R.string.localizable.aWalletTokenSellLinkExpiryTimeTitle(preferredLanguages: Languages.preferred())
    }
}
