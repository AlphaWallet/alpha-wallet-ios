//
//  TokenCardTableViewCellFactory.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.11.2021.
//

import UIKit

typealias TokenCardViewType = UIView & TokenCardRowViewProtocol & SelectionPositioningView

class TokenCardTableViewCellFactory {

    func create(for tokenHolder: TokenHolder, edgeInsets: UIEdgeInsets = .init(top: 16, left: 20, bottom: 16, right: 16)) -> TokenCardViewType {
        var rowView: TokenCardViewType
        switch tokenHolder.tokenType {
        case .erc875:
            rowView = Erc875NonFungibleRowView(tokenView: .view, edgeInsets: edgeInsets)
        case .nativeCryptocurrency, .erc20, .erc721, .erc721ForTickets, .erc1155:
            rowView = NonFungibleRowView(tokenView: .viewIconified, edgeInsets: edgeInsets)
        }
        rowView.shouldOnlyRenderIfHeightIsCached = false
        return rowView
    }

}
