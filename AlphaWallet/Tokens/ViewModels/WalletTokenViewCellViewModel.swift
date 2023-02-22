//
//  WalletTokenViewCellViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.06.2021.
//

import UIKit
import BigInt
import AlphaWalletFoundation
import Combine

struct WalletTokenViewCellViewModel {
    private let token: TokenViewModel
    private let isVisible: Bool
    private let tokenImageFetcher: TokenImageFetcher

    init(token: TokenViewModel,
         isVisible: Bool = true,
         tokenImageFetcher: TokenImageFetcher) {

        self.tokenImageFetcher = tokenImageFetcher
        self.token = token
        self.isVisible = isVisible
    }

    var cryptoValueAttributedString: NSAttributedString {
        return NSAttributedString(string: String(), attributes: [
            .foregroundColor: Screen.TokenCard.Color.title,
            .font: Screen.TokenCard.Font.title
        ])
    }

    var titleAttributedString: NSAttributedString {
        return NSAttributedString(string: token.tokenScriptOverrides?.safeShortTitleInPluralForm ?? "", attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText,
            .font: Screen.TokenCard.Font.title
        ])
    }

    var alpha: CGFloat {
        return isVisible ? 1.0 : 0.4
    }

    var iconImage: TokenImagePublisher {
        tokenImageFetcher.image(token: token, size: .s300)
    }

    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        return .init(server: token.server)
    }
}
