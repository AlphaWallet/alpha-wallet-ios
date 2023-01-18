// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

struct GenerateTransferMagicLinkViewModel {
    private let tokenHolder: TokenHolder
    private let linkExpiryDate: Date
    private let assetDefinitionStore: AssetDefinitionStore

    var contentsBackgroundColor: UIColor {
        return Configuration.Color.Semantic.defaultViewBackground
    }
    var subtitleColor: UIColor {
        return Configuration.Color.Semantic.defaultForegroundText
    }
    var subtitleFont: UIFont {
        return Fonts.regular(size: 25)
    }
    var subtitleLabelText: String {
        return R.string.localizable.aWalletTokenTransferConfirmSubtitle()
    }

	var headerTitle: String {
		return R.string.localizable.aWalletTokenTransferConfirmTitle()
	}

    var actionButtonTitleColor: UIColor {
        return Configuration.Color.Semantic.defaultForegroundText
    }
    var actionButtonBackgroundColor: UIColor {
        return Configuration.Color.Semantic.actionButtonBackground
    }
    var actionButtonTitleFont: UIFont {
        return Fonts.regular(size: 20)
    }
    var cancelButtonTitleColor: UIColor {
        return Configuration.Color.Semantic.cancelButtonTitle
    }
    var cancelButtonBackgroundColor: UIColor {
        return .clear
    }
    var cancelButtonTitleFont: UIFont {
        return Fonts.regular(size: 20)
    }
    var actionButtonTitle: String {
        return R.string.localizable.aWalletTokenSellConfirmButtonTitle()
    }
    var cancelButtonTitle: String {
        return R.string.localizable.aWalletTokenSellConfirmCancelButtonTitle()
    }

    var tokenSaleDetailsLabelFont: UIFont {
        return Fonts.semibold(size: 21)
    }

    var tokenSaleDetailsLabelColor: UIColor {
        return Configuration.Color.Semantic.defaultForegroundText
    }

    var descriptionLabelText: String {
        return R.string.localizable.aWalletTokenSellConfirmExpiryDateDescription(linkExpiryDate.format("dd MMM yyyy  hh:mm"))
    }

    var tokenCountLabelText: String {
        if tokenCount == 1 {
            let tokenTypeName = XMLHandler(contract: tokenHolder.contractAddress, tokenType: tokenHolder.tokenType, assetDefinitionStore: assetDefinitionStore).getLabel()
            return R.string.localizable.aWalletTokenSellConfirmSingleTokenSelectedTitle(tokenTypeName)
        } else {
            let tokenTypeName = XMLHandler(contract: tokenHolder.contractAddress, tokenType: tokenHolder.tokenType, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
            return R.string.localizable.aWalletTokenSellConfirmMultipleTokenSelectedTitle(tokenHolder.count, tokenTypeName)
        }
    }

    var detailsBackgroundBackgroundColor: UIColor {
        return Configuration.Color.Semantic.defaultViewBackground
    }

    private var tokenCount: Int {
        return tokenHolder.count
    }

    init(tokenHolder: TokenHolder, linkExpiryDate: Date, assetDefinitionStore: AssetDefinitionStore) {
        self.tokenHolder = tokenHolder
        self.linkExpiryDate = linkExpiryDate
        self.assetDefinitionStore = assetDefinitionStore
    }
}
