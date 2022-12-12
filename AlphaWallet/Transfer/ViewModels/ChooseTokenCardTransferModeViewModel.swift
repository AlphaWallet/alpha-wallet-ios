// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

struct ChooseTokenCardTransferModeViewModel {
    var token: Token
    var tokenHolder: TokenHolder
    let assetDefinitionStore: AssetDefinitionStore

    var headerTitle: String {
        let tokenTypeName = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
        return R.string.localizable.aWalletTokenTransferSelectQuantityTitle(tokenTypeName)
    }
}
