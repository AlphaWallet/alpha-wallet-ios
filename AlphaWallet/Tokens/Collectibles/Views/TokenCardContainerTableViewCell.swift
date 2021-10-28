//
//  TokenCardContainerTableViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.11.2021.
//

import UIKit

class TokenCardContainerTableViewCell: ContainerTableViewCell {
    weak var delegate: BaseTokenCardTableViewCellDelegate?

    var subview: (TokenCardRowViewProtocol & UIView)? {
        viewContainerView.subviews.compactMap { $0 as? (TokenCardRowViewProtocol & UIView) }.first
    }

    func configure(viewModel: BaseTokenCardTableViewCellViewModel, tokenId: TokenId, assetDefinitionStore: AssetDefinitionStore) {
        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor
        contentView.backgroundColor = viewModel.backgroundColor
        accessoryType = .disclosureIndicator

        subview?.configure(tokenHolder: viewModel.tokenHolder, tokenId: tokenId, tokenView: viewModel.tokenView, areDetailsVisible: viewModel.areDetailsVisible, width: viewModel.cellWidth, assetDefinitionStore: assetDefinitionStore)
    }
}

extension TokenCardContainerTableViewCell: OpenSeaNonFungibleTokenCardRowViewDelegate {
    func didTapURL(url: URL) {
        delegate?.didTapURL(url: url)
    }
}
