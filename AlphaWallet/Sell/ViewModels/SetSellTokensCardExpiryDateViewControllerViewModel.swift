// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct SetSellTokensCardExpiryDateViewControllerViewModel {
    private let ethCost: Ether
    private let server: RPCServer
    private let assetDefinitionStore: AssetDefinitionStore

    let token: TokenObject
    let tokenHolder: TokenHolder

    var headerTitle: String {
		return R.string.localizable.aWalletTokenSellEnterLinkExpiryDateTitle()
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
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
        let tokenTypeName = XMLHandler(contract: token.contractAddress, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
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
            let tokenTypeName = XMLHandler(contract: token.contractAddress, assetDefinitionStore: assetDefinitionStore).getName()
            return R.string.localizable.aWalletTokenSellSingleTokenSelectedTitle(tokenTypeName)
        } else {
            let tokenTypeName = XMLHandler(contract: token.contractAddress, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
            return R.string.localizable.aWalletTokenSellMultipleTokenSelectedTitle(tokenHolder.count, tokenTypeName)
        }
    }

    var perTokenPriceLabelText: String {
        let tokenTypeName = XMLHandler(contract: token.contractAddress, assetDefinitionStore: assetDefinitionStore).getName()
        let amount = ethCost / tokenCount
        return R.string.localizable.aWalletTokenSellPerTokenEthPriceTitle(amount.formattedDescription, server.symbol, tokenTypeName)
    }

    var totalEthLabelText: String {
        return R.string.localizable.aWalletTokenSellTotalEthPriceTitle(ethCost.formattedDescription, server.symbol)
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
        let tokenTypeName = XMLHandler(contract: token.contractAddress, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
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

    var noteCornerRadius: CGFloat {
        return Metrics.CornerRadius.box
    }

    private var tokenCount: Int {
        return tokenHolder.count
    }

    init(token: TokenObject, tokenHolder: TokenHolder, ethCost: Ether, server: RPCServer, assetDefinitionStore: AssetDefinitionStore) {
        self.token = token
        self.tokenHolder = tokenHolder
        self.ethCost = ethCost
        self.server = server
        self.assetDefinitionStore = assetDefinitionStore
    }
}
