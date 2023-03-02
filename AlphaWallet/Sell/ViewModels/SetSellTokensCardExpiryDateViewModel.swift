// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

struct SetSellTokensCardExpiryDateViewModel {
    private let session: WalletSession

    let ethCost: Double
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
        let tokenTypeName = session.tokenAdaptor.xmlHandler(token: token).getNameInPluralForm()
        return R.string.localizable.aWalletTokenSellMagicLinkDescriptionTitle(tokenTypeName)
    }

    var tokenCountLabelText: String {
        if tokenCount == 1 {
            let tokenTypeName = session.tokenAdaptor.xmlHandler(token: token).getLabel()
            return R.string.localizable.aWalletTokenSellSingleTokenSelectedTitle(tokenTypeName)
        } else {
            let tokenTypeName = session.tokenAdaptor.xmlHandler(token: token).getNameInPluralForm()
            return R.string.localizable.aWalletTokenSellMultipleTokenSelectedTitle(tokenHolder.count, tokenTypeName)
        }
    }
    
    var perTokenPriceLabelText: String {
        let tokenTypeName = session.tokenAdaptor.xmlHandler(token: token).getLabel()
        let amount = NumberFormatter.shortCrypto.string(double: ethCost / Double(tokenCount), minimumFractionDigits: 4, maximumFractionDigits: 8).droppedTrailingZeros
        
        return R.string.localizable.aWalletTokenSellPerTokenEthPriceTitle(amount, session.server.symbol, tokenTypeName)
    }
    
    var totalEthLabelText: String {
        let amount = NumberFormatter.shortCrypto.string(double: ethCost, minimumFractionDigits: 4, maximumFractionDigits: 8).droppedTrailingZeros

        return R.string.localizable.aWalletTokenSellTotalEthPriceTitle(amount, session.server.symbol)
    }
    
    var noteTitleLabelText: String {
        return R.string.localizable.aWalletTokenSellNoteTitleLabelTitle()
    }

    var noteLabelText: String {
        let tokenTypeName = session.tokenAdaptor.xmlHandler(token: token).getNameInPluralForm()
        return R.string.localizable.aWalletTokenSellNoteLabelTitle(tokenTypeName)
    }
    
    private var tokenCount: Int {
        return tokenHolder.count
    }
    
    init(token: Token,
         tokenHolder: TokenHolder,
         ethCost: Double,
         session: WalletSession) {

        self.token = token
        self.tokenHolder = tokenHolder
        self.ethCost = ethCost
        self.session = session
    }
}
