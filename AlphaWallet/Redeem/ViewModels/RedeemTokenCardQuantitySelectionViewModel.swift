//
//  QuantitySelectionViewModel.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/4/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit

struct RedeemTokenCardQuantitySelectionViewModel {
    let token: TokenObject
    let tokenHolder: TokenHolder
    let assetDefinitionStore: AssetDefinitionStore

    var headerTitle: String {
        let tokenTypeName = XMLHandler(contract: token.address.eip55String, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
		return R.string.localizable.aWalletTokenRedeemSelectQuantityTitle(tokenTypeName)
    }

    var maxValue: Int {
        return tokenHolder.tokens.count
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var subtitleColor: UIColor {
        return Colors.appGrayLabelColor
    }

    var subtitleFont: UIFont {
        return Fonts.regular(size: 10)!
    }

    var stepperBorderColor: UIColor {
        return Colors.appBackground
    }

    var subtitleText: String {
        let tokenTypeName = XMLHandler(contract: token.address.eip55String, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
		return R.string.localizable.aWalletTokenRedeemQuantityTitle(tokenTypeName.localizedUppercase)
    }
}
