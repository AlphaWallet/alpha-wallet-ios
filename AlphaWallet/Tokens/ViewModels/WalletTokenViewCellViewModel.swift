//
//  WalletTokenViewCellViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.06.2021.
//

import UIKit
import BigInt
import AlphaWalletFoundation

struct WalletTokenViewCellViewModel {
    private let token: TokenViewModel
    private let isVisible: Bool

    init(token: TokenViewModel, isVisible: Bool = true) {
        self.token = token
        self.isVisible = isVisible
    }

    var cryptoValueAttributedString: NSAttributedString {
        return NSAttributedString(string: String(), attributes: [
            .foregroundColor: Screen.TokenCard.Color.title,
            .font: Screen.TokenCard.Font.title
        ])
    }

    var backgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }

    var contentsBackgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }

    var titleAttributedString: NSAttributedString {
        return NSAttributedString(string: token.tokenScriptOverrides?.titleInPluralForm ?? "", attributes: [
            .foregroundColor: Screen.TokenCard.Color.title,
            .font: Screen.TokenCard.Font.title
        ])
    }

    var alpha: CGFloat {
        return isVisible ? 1.0 : 0.4
    }

    var iconImage: Subscribable<TokenImage> {
        token.icon(withSize: .s300)
    }

    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        return .init(server: token.server)
    }
}
