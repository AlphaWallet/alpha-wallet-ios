//
//  QuantitySelectionViewModel.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/4/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit
import AlphaWalletFoundation

struct RedeemTokenCardQuantitySelectionViewModel {
    let token: Token
    let tokenHolder: TokenHolder
    let assetDefinitionStore: AssetDefinitionStore

    var headerTitle: String {
        let tokenTypeName = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
		return R.string.localizable.aWalletTokenRedeemSelectQuantityTitle(tokenTypeName)
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
        return Fonts.regular(size: 10)
    }

    var subtitleText: String {
        let tokenTypeName = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
		return R.string.localizable.aWalletTokenRedeemQuantityTitle(tokenTypeName.localizedUppercase)
    }
}

extension XMLHandler {
    func getLabel() -> String {
        let name = getLabel(fallback: R.string.localizable.tokenTitlecase())
        if name == Constants.katNameFallback {
            return R.string.localizable.katTitlecase()
        } else {
            return name
        }
    }

    func getNameInPluralForm() -> String {
        let name = getNameInPluralForm(fallback: R.string.localizable.tokensTitlecase())
        if name == Constants.katNameFallback {
            return R.string.localizable.katTitlecase()
        } else {
            return name
        }
    }
}

