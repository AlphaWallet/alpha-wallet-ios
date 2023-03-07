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
    private let wallet: Wallet
    private let tokenImageFetcher: TokenImageFetcher

    let assetDefinitionStore: AssetDefinitionStore
    
    init(token: Token,
         assetDefinitionStore: AssetDefinitionStore,
         wallet: Wallet,
         tokenImageFetcher: TokenImageFetcher) {

        self.tokenImageFetcher = tokenImageFetcher
        self.token = token
        self.assetDefinitionStore = assetDefinitionStore
        self.wallet = wallet
    }

    func createPreview(of type: NFTPreviewViewType,
                       session: WalletSession,
                       edgeInsets: UIEdgeInsets = .zero,
                       playButtonPositioning: AVPlayerView.PlayButtonPositioning) -> NFTPreviewViewRepresentable {

        return NFTPreviewView(
            type: type,
            session: session,
            assetDefinitionStore: assetDefinitionStore,
            edgeInsets: edgeInsets,
            playButtonPositioning: playButtonPositioning)
    }

    func createTokenCardView(for tokenHolder: TokenHolder,
                             layout: GridOrListLayout,
                             gridEdgeInsets: UIEdgeInsets = .zero,
                             listEdgeInsets: UIEdgeInsets = .init(top: 0, left: 16, bottom: 0, right: 16)) -> TokenCardViewRepresentable {

        var rowView: TokenCardViewRepresentable

        let tokenType = OpenSeaBackedNonFungibleTokenHandling(
            token: token,
            assetDefinitionStore: assetDefinitionStore,
            tokenViewType: .viewIconified)

        switch tokenHolder.tokenType {
        case .erc875, .erc721ForTickets:
            rowView = Erc875NonFungibleRowView(
                token: token,
                tokenType: tokenType,
                assetDefinitionStore: assetDefinitionStore,
                wallet: wallet,
                layout: layout,
                gridEdgeInsets: gridEdgeInsets,
                listEdgeInsets: listEdgeInsets,
                tokenImageFetcher: tokenImageFetcher)

        case .nativeCryptocurrency, .erc20, .erc721, .erc1155:
            rowView = NonFungibleRowView(
                layout: layout,
                gridEdgeInsets: gridEdgeInsets,
                listEdgeInsets: listEdgeInsets)
        } 

        return rowView
    }

}
