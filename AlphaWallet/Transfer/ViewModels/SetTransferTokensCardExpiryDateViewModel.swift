// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

struct SetTransferTokensCardExpiryDateViewModel {
    let token: Token
    let tokenHolder: TokenHolder
    let assetDefinitionStore: AssetDefinitionStore

    var headerTitle: String {
        let tokenTypeName = assetDefinitionStore.xmlHandler(forTokenScriptSupportable: token).getNameInPluralForm()
        return R.string.localizable.aWalletTokenTransferSelectQuantityTitle(tokenTypeName)
    }

    var descriptionLabelText: String {
        return R.string.localizable.aWalletTokenTransferMagicLinkDescriptionTitle()
    }

    var noteTitleLabelText: String {
        return R.string.localizable.aWalletTokenSellNoteTitleLabelTitle()
    }

    var noteLabelText: String {
        return R.string.localizable.aWalletTokenTransferNoteLabelTitle()
    }

    var linkExpiryDateLabelText: String {
        return R.string.localizable.aWalletTokenSellLinkExpiryDateTitle()
    }

    var linkExpiryTimeLabelText: String {
        return R.string.localizable.aWalletTokenSellLinkExpiryTimeTitle()
    }
}
