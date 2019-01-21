// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct TransferTokensCardViaWalletAddressViewControllerViewModel {
    let token: TokenObject
    let tokenHolder: TokenHolder

    var headerTitle: String {
        let tokenTypeName = XMLHandler(contract: token.address.eip55String).getTokenTypeName(.plural, titlecase: .titlecase)
		return R.string.localizable.aWalletTokenTransferSelectQuantityTitle(tokenTypeName)
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var buttonTitleColor: UIColor {
        return Colors.appWhite
    }

    var buttonBackgroundColor: UIColor {
        return Colors.appHighlightGreen
    }

    var buttonFont: UIFont {
        return Fonts.regular(size: 20)!
    }

    var actionButtonCornerRadius: CGFloat {
        return 16
    }

    var actionButtonShadowColor: UIColor {
        return .black
    }

    var actionButtonShadowOffset: CGSize {
        return .init(width: 1, height: 2)
    }

    var actionButtonShadowOpacity: Float {
        return 0.3
    }

    var actionButtonShadowRadius: CGFloat {
        return 5
    }
}
