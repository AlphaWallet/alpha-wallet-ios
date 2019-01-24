// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct ChooseTokenCardTransferModeViewControllerViewModel {
    var token: TokenObject
    var tokenHolder: TokenHolder

    var headerTitle: String {
        let tokenTypeName = XMLHandler(contract: token.address.eip55String).getTokenTypeName(.plural, titlecase: .titlecase)
		return R.string.localizable.aWalletTokenTransferSelectQuantityTitle(tokenTypeName)
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var buttonFont: UIFont {
        if ScreenChecker().isNarrowScreen() {
            return Fonts.regular(size: 13)!
        } else {
            return Fonts.regular(size: 16)!
        }
    }
}
