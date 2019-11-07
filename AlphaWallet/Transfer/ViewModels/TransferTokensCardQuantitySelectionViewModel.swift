// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct TransferTokensCardQuantitySelectionViewModel {
    let token: TokenObject
    let tokenHolder: TokenHolder
    let assetDefinitionStore: AssetDefinitionStore

    var headerTitle: String {
        let tokenTypeName = XMLHandler(contract: token.contractAddress, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
		return R.string.localizable.aWalletTokenTransferSelectQuantityTitle(tokenTypeName)
    }

    var maxValue: Int {
        return tokenHolder.tokens.count
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var subtitleColor: UIColor {
        return Colors.appText
    }

    var subtitleFont: UIFont {
        return Fonts.regular(size: 10)!
    }

    var subtitleText: String {
        let tokenTypeName = XMLHandler(contract: token.contractAddress, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
		return R.string.localizable.aWalletTokenTransferQuantityTitle(tokenTypeName.localizedUppercase)
    }
}
