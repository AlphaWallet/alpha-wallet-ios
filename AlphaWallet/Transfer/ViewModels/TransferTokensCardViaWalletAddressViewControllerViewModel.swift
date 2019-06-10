// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct TransferTokensCardViaWalletAddressViewControllerViewModel {
    let token: TokenObject
    let tokenHolder: TokenHolder
    let assetDefinitionStore: AssetDefinitionStore

    var headerTitle: String {
        let tokenTypeName = XMLHandler(contract: token.address.eip55String, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
		return R.string.localizable.aWalletTokenTransferSelectQuantityTitle(tokenTypeName)
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }
}
