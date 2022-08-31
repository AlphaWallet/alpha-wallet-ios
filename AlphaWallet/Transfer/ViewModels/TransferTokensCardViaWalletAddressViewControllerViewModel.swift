// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

struct TransferTokensCardViaWalletAddressViewControllerViewModel {
    let token: Token
    let tokenHolder: TokenHolder
    let assetDefinitionStore: AssetDefinitionStore

    var headerTitle: String {
        let tokenTypeName = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
		return R.string.localizable.aWalletTokenTransferSelectQuantityTitle(tokenTypeName)
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var targetAddressLabelFont: UIFont {
        return Fonts.regular(size: 13)
    }

    var targetAddressLabelTextColor: UIColor {
        return R.color.dove()!
    }
}
