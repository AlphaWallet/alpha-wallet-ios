// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct GenerateTransferMagicLinkViewControllerViewModel {
    var tokenHolder: TokenHolder
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
        return R.string.localizable.aWalletTokenTransferConfirmSubtitle()
    }

	var headerTitle: String {
		return R.string.localizable.aWalletTokenTransferConfirmTitle()
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
        return R.string.localizable.aWalletTokenSellConfirmButtonTitle()
    }
    var cancelButtonTitle: String {
        return R.string.localizable.aWalletTokenSellConfirmCancelButtonTitle()
    }

    var tokenSaleDetailsLabelFont: UIFont {
        return Fonts.semibold(size: 21)!
    }

    var tokenSaleDetailsLabelColor: UIColor {
        return Colors.appBackground
    }

    var descriptionLabelText: String {
        return R.string.localizable.aWalletTokenSellConfirmExpiryDateDescription(linkExpiryDate.format("dd MMM yyyy  hh:mm"))
    }

    var tokenCountLabelText: String {
        if tokenCount == 1 {
            let tokenTypeName = XMLHandler(contract: tokenHolder.contractAddress).getTokenTypeName(.singular, titlecase: .titlecase)
            return R.string.localizable.aWalletTokenSellConfirmSingleTokenSelectedTitle(tokenTypeName)
        } else {
            let tokenTypeName = XMLHandler(contract: tokenHolder.contractAddress).getTokenTypeName(.plural, titlecase: .titlecase)
            return R.string.localizable.aWalletTokenSellConfirmMultipleTokenSelectedTitle(tokenHolder.count, tokenTypeName)
        }
    }

    var detailsBackgroundBackgroundColor: UIColor {
        return UIColor(red: 236, green: 236, blue: 236)
    }

    private var tokenCount: Int {
        return tokenHolder.count
    }

    init(tokenHolder: TokenHolder, linkExpiryDate: Date) {
        self.tokenHolder = tokenHolder
        self.linkExpiryDate = linkExpiryDate
    }
}
