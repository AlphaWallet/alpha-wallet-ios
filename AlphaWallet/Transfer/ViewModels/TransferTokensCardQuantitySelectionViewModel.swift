// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

struct TransferTokensCardQuantitySelectionViewModel {
    let token: Token
    let tokenHolder: TokenHolder
    let assetDefinitionStore: AssetDefinitionStore
    let session: WalletSession
    var headerTitle: String {
        let tokenTypeName = assetDefinitionStore.xmlHandler(forTokenScriptSupportable: token).getNameInPluralForm()
		return R.string.localizable.aWalletTokenTransferSelectQuantityTitle(tokenTypeName)
    }

    var maxValue: Int {
        return tokenHolder.tokens.count
    }

    var subtitleText: String {
        let tokenTypeName = assetDefinitionStore.xmlHandler(forTokenScriptSupportable: token).getNameInPluralForm()
		return R.string.localizable.aWalletTokenTransferQuantityTitle(tokenTypeName.localizedUppercase)
    }
}
