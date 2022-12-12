// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

struct SetSellTokensCardExpiryDateViewModel {
    private let ethCost: Ether
    private let server: RPCServer
    private let assetDefinitionStore: AssetDefinitionStore
    
    let token: Token
    let tokenHolder: TokenHolder
    
    var headerTitle: String {
        return R.string.localizable.aWalletTokenSellEnterLinkExpiryDateTitle()
    }

    var linkExpiryDateLabelText: String {
        return R.string.localizable.aWalletTokenSellLinkExpiryDateTitle()
    }
    
    var linkExpiryTimeLabelText: String {
        return R.string.localizable.aWalletTokenSellLinkExpiryTimeTitle()
    }
    
    var descriptionLabelText: String {
        let tokenTypeName = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
        return R.string.localizable.aWalletTokenSellMagicLinkDescriptionTitle(tokenTypeName)
    }

    var tokenCountLabelText: String {
        if tokenCount == 1 {
            let tokenTypeName = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore).getLabel()
            return R.string.localizable.aWalletTokenSellSingleTokenSelectedTitle(tokenTypeName)
        } else {
            let tokenTypeName = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
            return R.string.localizable.aWalletTokenSellMultipleTokenSelectedTitle(tokenHolder.count, tokenTypeName)
        }
    }
    
    var perTokenPriceLabelText: String {
        let tokenTypeName = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore).getLabel()
        let amount = ethCost / tokenCount
        return R.string.localizable.aWalletTokenSellPerTokenEthPriceTitle(amount.formattedDescription, server.symbol, tokenTypeName)
    }
    
    var totalEthLabelText: String {
        return R.string.localizable.aWalletTokenSellTotalEthPriceTitle(ethCost.formattedDescription, server.symbol)
    }
    
    var noteTitleLabelText: String {
        return R.string.localizable.aWalletTokenSellNoteTitleLabelTitle()
    }

    var noteLabelText: String {
        let tokenTypeName = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
        return R.string.localizable.aWalletTokenSellNoteLabelTitle(tokenTypeName)
    }
    
    private var tokenCount: Int {
        return tokenHolder.count
    }
    
    init(token: Token, tokenHolder: TokenHolder, ethCost: Ether, server: RPCServer, assetDefinitionStore: AssetDefinitionStore) {
        self.token = token
        self.tokenHolder = tokenHolder
        self.ethCost = ethCost
        self.server = server
        self.assetDefinitionStore = assetDefinitionStore
    }
}
