// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct ChooseTokenCardTransferModeViewControllerViewModel {
    var token: TokenObject
    var tokenHolder: TokenHolder
    let assetDefinitionStore: AssetDefinitionStore

    var headerTitle: String {
        let tokenTypeName = XMLHandler(contract: token.address.eip55String, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
		return R.string.localizable.aWalletTokenTransferSelectQuantityTitle(tokenTypeName)
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var buttonFont: UIFont {
        if ScreenChecker().isNarrowScreen() {
            return Fonts.regular(size: 12)!
        } else {
            return Fonts.regular(size: 15)!
        }
    }
}
