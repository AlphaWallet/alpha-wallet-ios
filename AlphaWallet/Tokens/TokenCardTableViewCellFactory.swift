//
//  TokenCardViewFactory.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.11.2021.
//

import UIKit
import AlphaWalletFoundation

protocol TokenCardRowViewLayoutConfigurable {
    func configureLayout(layout: GridOrListLayout)
}

protocol TokenCardRowViewConfigurable {
    func configure(tokenHolder: TokenHolder, tokenId: TokenId)
}

typealias TokenCardViewRepresentable = UIView & TokenCardRowViewConfigurable & SelectionPositioningView & TokenCardRowViewLayoutConfigurable

final class TokenCardViewFactory {
    private let token: Token
    private let analytics: AnalyticsLogger
    private let keystore: Keystore
    private let wallet: Wallet

    let assetDefinitionStore: AssetDefinitionStore
    
    init(token: Token, assetDefinitionStore: AssetDefinitionStore, analytics: AnalyticsLogger, keystore: Keystore, wallet: Wallet) {
        self.token = token
        self.assetDefinitionStore = assetDefinitionStore
        self.analytics = analytics
        self.keystore = keystore
        self.wallet = wallet
    }

    func createPreview(of type: NFTPreviewViewType, session: WalletSession, edgeInsets: UIEdgeInsets = .zero) -> NFTPreviewViewRepresentable {
        return NFTPreviewView(type: type, keystore: keystore, session: session, assetDefinitionStore: assetDefinitionStore, analytics: analytics, edgeInsets: edgeInsets)
    }

    func createTokenCardView(for tokenHolder: TokenHolder, layout: GridOrListLayout, gridEdgeInsets: UIEdgeInsets = .zero, listEdgeInsets: UIEdgeInsets = .init(top: 0, left: 16, bottom: 0, right: 16)) -> TokenCardViewRepresentable {
        var rowView: TokenCardViewRepresentable

        let tokenType = OpenSeaBackedNonFungibleTokenHandling(token: token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified)

        switch tokenHolder.tokenType {
        case .erc875, .erc721ForTickets:
            rowView = Erc875NonFungibleRowView(token: token, tokenType: tokenType, analytics: analytics, keystore: keystore, assetDefinitionStore: assetDefinitionStore, wallet: wallet, layout: layout, gridEdgeInsets: gridEdgeInsets, listEdgeInsets: listEdgeInsets)
        case .nativeCryptocurrency, .erc20, .erc721, .erc1155:
            rowView = NonFungibleRowView(layout: layout, gridEdgeInsets: gridEdgeInsets, listEdgeInsets: listEdgeInsets)
        } 

        return rowView
    }

}
