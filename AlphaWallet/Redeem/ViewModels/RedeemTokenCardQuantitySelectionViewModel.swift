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
import AlphaWalletTokenScript

struct RedeemTokenCardQuantitySelectionViewModel {
    let token: Token
    let tokenHolder: TokenHolder
    let assetDefinitionStore: AssetDefinitionStore
    let session: WalletSession

    var headerTitle: String {
        let tokenTypeName = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
        return R.string.localizable.aWalletTokenRedeemSelectQuantityTitle(tokenTypeName)
    }

    var maxValue: Int {
        return tokenHolder.tokens.count
    }

    var subtitleText: String {
        let tokenTypeName = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm()
        return R.string.localizable.aWalletTokenRedeemQuantityTitle(tokenTypeName.localizedUppercase)
    }
}

extension XMLHandler {
    func getLabel() -> String {
        let name = getLabel(fallback: R.string.localizable.tokenTitlecase())
        if name == AlphaWalletTokenScript.Constants.katNameFallback {
            return R.string.localizable.katTitlecase()
        } else {
            return name
        }
    }

    func getNameInPluralForm() -> String {
        let name = getNameInPluralForm(fallback: R.string.localizable.tokensTitlecase())
        if name == AlphaWalletTokenScript.Constants.katNameFallback {
            return R.string.localizable.katTitlecase()
        } else {
            return name
        }
    }
}
