//
//  TokenCardViewFactory.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.11.2021.
//

import UIKit

protocol TokenCardRowViewLayoutConfigurableProtocol {
    func configureLayout(layout: GridOrListSelectionState)
}

protocol TokenCardRowViewConfigurable {
    func configure(tokenHolder: TokenHolder, tokenId: TokenId)
}

typealias TokenCardViewType = UIView & TokenCardRowViewConfigurable & SelectionPositioningView & TokenCardRowViewLayoutConfigurableProtocol

class TokenCardViewFactory {
    private let token: Token
    private let analyticsCoordinator: AnalyticsCoordinator
    private let keystore: Keystore
    private let wallet: Wallet

    let assetDefinitionStore: AssetDefinitionStore
    
    init(token: Token, assetDefinitionStore: AssetDefinitionStore, analyticsCoordinator: AnalyticsCoordinator, keystore: Keystore, wallet: Wallet) {
        self.token = token
        self.assetDefinitionStore = assetDefinitionStore
        self.analyticsCoordinator = analyticsCoordinator
        self.keystore = keystore
        self.wallet = wallet
    }

    func create(for tokenHolder: TokenHolder, layout: GridOrListSelectionState, gridEdgeInsets: UIEdgeInsets = .zero, listEdgeInsets: UIEdgeInsets = .init(top: 0, left: 16, bottom: 0, right: 16)) -> TokenCardViewType {
        var rowView: TokenCardViewType

        let tokenType = OpenSeaBackedNonFungibleTokenHandling(token: token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified)

        switch tokenHolder.tokenType {
        case .erc875:
            rowView = Erc875NonFungibleRowView(token: token, tokenType: tokenType, analyticsCoordinator: analyticsCoordinator, keystore: keystore, assetDefinitionStore: assetDefinitionStore, wallet: wallet, layout: layout, gridEdgeInsets: gridEdgeInsets, listEdgeInsets: listEdgeInsets)
        case .nativeCryptocurrency, .erc20, .erc721, .erc721ForTickets, .erc1155:
            rowView = NonFungibleRowView(layout: layout, gridEdgeInsets: gridEdgeInsets, listEdgeInsets: listEdgeInsets)
        } 

        return rowView
    }

}
