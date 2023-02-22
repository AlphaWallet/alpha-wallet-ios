//
//  FungibleTokenViewCellViewModel3.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.06.2021.
//

import UIKit
import AlphaWalletFoundation
import Combine

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

    var titleAttributedString: NSAttributedString {
        return NSAttributedString(string: title, attributes: [
            .foregroundColor: Configuration.Color.Semantic.tableViewCellPrimaryFont,
            .font: Screen.TokenCard.Font.title
        ])
    }

    var alpha: CGFloat {
        return isVisible ? 1.0 : 0.4
    }

    var iconImage: TokenImagePublisher {
        TokenImageFetcher.instance.image(token: token, size: .s120)
    }

    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        return .init(server: token.server)
    }
}

