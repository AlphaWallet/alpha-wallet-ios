//
//  FungibleTokenViewCellViewModel3.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.06.2021.
//

import UIKit

struct PopularTokenViewCellViewModel {
    private let token: PopularToken
    private let isVisible: Bool

    init(token: PopularToken, isVisible: Bool = true) {
        self.token = token
        self.isVisible = isVisible
    }

    private var title: String {
        return token.name
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var contentsBackgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }

    var titleAttributedString: NSAttributedString {
        return NSAttributedString(string: title, attributes: [
            .foregroundColor: Screen.TokenCard.Color.title,
            .font: Fonts.bold(size: 14)
        ])
    }

    var alpha: CGFloat {
        return 1.0
    }
    
    var visible: Bool {
        return isVisible
    }

    var iconImage: Subscribable<TokenImage> {
        token.iconImage
    }

    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        return .init(server: token.server)
    }
}

