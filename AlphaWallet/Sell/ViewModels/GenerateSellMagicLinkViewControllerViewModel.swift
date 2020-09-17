// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct GenerateSellMagicLinkViewControllerViewModel {
    private let tokenHolder: TokenHolder
    private let ethCost: Ether
    private let linkExpiryDate: Date
    private let server: RPCServer
    private let assetDefinitionStore: AssetDefinitionStore

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
        return R.string.localizable.aWalletTokenSellConfirmSubtitle()
    }

	var headerTitle: String {
		return R.string.localizable.aWalletTokenSellConfirmTitle()
	}

    var actionButtonTitleColor: UIColor {
        return Colors.appWhite
    }
    var actionButtonBackgroundColor: UIColor {
        return Colors.appActionButtonGreen
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
        return Colors.appText
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

    var perTokenPriceLabelText: String {
        let tokenTypeName = XMLHandler(contract: tokenHolder.contractAddress, tokenType: tokenHolder.tokenType, assetDefinitionStore: assetDefinitionStore).getLabel()
        let amount = ethCost / tokenCount
        return R.string.localizable.aWalletTokenSellPerTokenEthPriceTitle(amount.formattedDescription, server.symbol, tokenTypeName)
    }

    var totalEthLabelText: String {
        return R.string.localizable.aWalletTokenSellTotalEthPriceTitle(ethCost.formattedDescription, server.symbol)
    }

    var detailsBackgroundBackgroundColor: UIColor {
        return UIColor(red: 236, green: 236, blue: 236)
    }

    private var tokenCount: Int {
        return tokenHolder.count
    }

    init(tokenHolder: TokenHolder, ethCost: Ether, linkExpiryDate: Date, server: RPCServer, assetDefinitionStore: AssetDefinitionStore) {
        self.tokenHolder = tokenHolder
        self.ethCost = ethCost
        self.linkExpiryDate = linkExpiryDate
        self.server = server
        self.assetDefinitionStore = assetDefinitionStore
    }
}
