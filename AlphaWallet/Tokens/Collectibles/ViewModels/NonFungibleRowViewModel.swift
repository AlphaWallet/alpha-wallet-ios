//
//  NonFungibleRowViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.11.2021.
//

import UIKit
import AlphaWalletFoundation

struct NonFungibleRowViewModel {
    private let tokenHolder: TokenHolder
    private let displayHelper: OpenSeaNonFungibleTokenDisplayHelper
    private let tokenId: TokenId

    var contentBackgroundColor: UIColor {
        if displayHelper.imageHasBackgroundColor {
            return Colors.appBackground
        } else {
            if let color = tokenHolder.values.backgroundColorStringValue.nilIfEmpty {
                return UIColor(hex: color)
            } else {
                return UIColor(red: 247, green: 197, blue: 196)
            }
        }
    }
    var backgroundColor: UIColor = Colors.appBackground
    var titleColor: UIColor = Screen.TokenCard.Color.title
    var titleFont: UIFont = Screen.TokenCard.Font.title

    var title: NSAttributedString {
        let string: String
        let tokenIdString = tokenHolder.values(tokenId: tokenId)?.tokenIdStringValue ?? ""
        if let name = tokenHolder.values(tokenId: tokenId)?.nameStringValue.nilIfEmpty {
            string = name
        } else {
            string = displayHelper.title(fromTokenName: tokenHolder.name, tokenId: tokenIdString)
        }

        return .init(string: string, attributes: [
            .font: titleFont,
            .foregroundColor: titleColor
        ])
    }

    var description: NSAttributedString {
        let assetCount = Int(tokenHolder.values(tokenId: tokenId)?.valueIntValue ?? 0)
        return .init(string: R.string.localizable.semifungiblesAssetsCount(assetCount), attributes: [
            .font: Screen.TokenCard.Font.subtitle,
            .foregroundColor: Screen.TokenCard.Color.subtitle
        ])
    }

    init(tokenHolder: TokenHolder, tokenId: TokenId) {
        self.tokenHolder = tokenHolder
        self.tokenId = tokenId
        self.displayHelper = OpenSeaNonFungibleTokenDisplayHelper(contract: tokenHolder.contractAddress)
    } 

    var assetImage: Subscribable<TokenImage> {
        let tokenImage = tokenHolder.assetImageUrl(tokenId: tokenId, rewriteGoogleContentSizeUrl: .s300)
            .flatMap { TokenImage(image: .url($0), symbol: "", isFinal: true, overlayServerIcon: nil) }

        return .init(tokenImage)
    }
}
