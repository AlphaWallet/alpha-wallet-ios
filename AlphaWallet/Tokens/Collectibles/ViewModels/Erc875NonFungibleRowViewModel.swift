//
//  Erc875NonFungibleRowViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.11.2021.
//

import UIKit
import AlphaWalletFoundation

struct Erc875NonFungibleRowViewModel {
    private let tokenHolder: TokenHolder
    private let displayHelper: OpenSeaNonFungibleTokenDisplayHelper
    private let tokenId: TokenId

    var contentsBackgroundColor: UIColor {
        return Colors.appBackground
    }

    init(tokenHolder: TokenHolder, tokenId: TokenId) {
        self.tokenHolder = tokenHolder
        self.tokenId = tokenId
        displayHelper = .init(contract: tokenHolder.contractAddress)
    }

    var titleTextFont: UIFont {
        return Screen.TokenCard.Font.title
    }

    var titleTextForegroundColor: UIColor {
        return Screen.TokenCard.Color.title
    }

    var titleText: String {
        return title
    }

    var title: String {
        let tokenId = tokenHolder.values.tokenIdStringValue ?? ""
        if let name = tokenHolder.values.nameStringValue.nilIfEmpty {
            return name
        } else {
            return displayHelper.title(fromTokenName: tokenHolder.name, tokenId: tokenId)
        }
    }

    var descriptionTextFont: UIFont {
        return Screen.TokenCard.Font.subtitle
    }

    var descriptionTextForegroundColor: UIColor {
        return Screen.TokenCard.Color.subtitle
    }

    var descriptionText: String {
        return R.string.localizable.semifungiblesAssetsCount(Int(tokenHolder.values.valueIntValue ?? 0))
    }
}
