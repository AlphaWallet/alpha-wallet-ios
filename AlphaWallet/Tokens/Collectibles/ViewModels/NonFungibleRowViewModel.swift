//
//  NonFungibleRowViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.11.2021.
//

import UIKit
import AlphaWalletFoundation
import Combine

struct NonFungibleRowViewModel {
    private let tokenHolder: TokenHolder
    private let displayHelper: OpenSeaNonFungibleTokenDisplayHelper
    private let tokenId: TokenId

    var contentBackgroundColor: UIColor {
        if displayHelper.imageHasBackgroundColor {
            return Configuration.Color.Semantic.defaultViewBackground
        } else {
            if let color = tokenHolder.values.backgroundColorStringValue.nilIfEmpty {
                return UIColor(hex: color)
            } else {
                return Configuration.Color.Semantic.nonFungibleRowViewContentBackgroundColor
            }
        }
    }
    var titleColor: UIColor = Configuration.Color.Semantic.defaultTitleText
    var titleFont: UIFont = Screen.TokenCard.Font.title

    var title: NSAttributedString {
        let string: String
        let tokenIdString = tokenHolder.values(tokenId: tokenId)?.tokenIdStringValue ?? ""
        if let name = tokenHolder.values(tokenId: tokenId)?.nameStringValue.nilIfEmpty {
            //Display the token ID at the end, there's a chance that it's already include in the name and be redundant, but it'll be much more readable if it wasn't
            string = displayHelper.title(fromTokenName: name, tokenId: tokenIdString)
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
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText
        ])
    }

    init(tokenHolder: TokenHolder, tokenId: TokenId) {
        self.tokenHolder = tokenHolder
        self.tokenId = tokenId
        self.displayHelper = OpenSeaNonFungibleTokenDisplayHelper(contract: tokenHolder.contractAddress)
    }

    var assetImage: TokenImagePublisher {
        let assetImage = tokenHolder.assetImageUrl(tokenId: tokenId, rewriteGoogleContentSizeUrl: .s300)
            .flatMap { TokenImage(image: .url($0), isFinal: true, overlayServerIcon: nil) }

        return .just(assetImage)
    }
}
