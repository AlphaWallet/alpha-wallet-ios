//
//  TokenCardTableViewCellFactory.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.11.2021.
//

import UIKit

protocol TokenCardRowViewLayoutConfigurableProtocol {
    func configureLayout(layout: GridOrListSelectionState)
}

typealias TokenCardViewType = UIView & TokenCardRowViewProtocol & SelectionPositioningView & TokenCardRowViewLayoutConfigurableProtocol

class TokenCardTableViewCellFactory {

    func create(for tokenHolder: TokenHolder, layout: GridOrListSelectionState, gridEdgeInsets: UIEdgeInsets = .zero, listEdgeInsets: UIEdgeInsets = .init(top: 0, left: 16, bottom: 0, right: 16)) -> TokenCardViewType {
        var rowView: TokenCardViewType
        switch tokenHolder.tokenType {
        case .erc875:
            rowView = Erc875NonFungibleRowView(tokenView: .view, layout: layout, gridEdgeInsets: gridEdgeInsets, listEdgeInsets: listEdgeInsets)
        case .nativeCryptocurrency, .erc20, .erc721, .erc721ForTickets, .erc1155:
            rowView = NonFungibleRowView(tokenView: .viewIconified, layout: layout, gridEdgeInsets: gridEdgeInsets, listEdgeInsets: listEdgeInsets)
        }

        rowView.configureLayout(layout: layout)
        rowView.shouldOnlyRenderIfHeightIsCached = false
        
        return rowView
    }

}
