//
//  NonFungibleRowView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.11.2021.
//

import UIKit

class NonFungibleRowView: TokenCardViewType {
    var checkboxImageView: UIImageView = UIImageView()
    var stateLabel: UILabel = UILabel()
    var tokenView: TokenView
    var showCheckbox: Bool = false
    var areDetailsVisible: Bool = false
    var additionalHeightToCompensateForAutoLayout: CGFloat = 0.0
    var shouldOnlyRenderIfHeightIsCached: Bool = false

    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()

    var positioningView: UIView {
        thumbnailImageView
    }

    private var thumbnailImageView: WebImageView = {
        let imageView = WebImageView()
        return imageView
    }()

    init(tokenView: TokenView, edgeInsets: UIEdgeInsets = .init(top: 16, left: 20, bottom: 16, right: 16)) {
        self.tokenView = tokenView
        super.init(frame: .zero)

        titleLabel.baselineAdjustment = .alignCenters
        descriptionLabel.baselineAdjustment = .alignCenters

        let col0 = thumbnailImageView
        let col1 = [
            [titleLabel, UIView.spacerWidth(flexible: true)].asStackView(spacing: 5),
            [descriptionLabel, UIView.spacerWidth(flexible: true)].asStackView(spacing: 5)
        ].asStackView(axis: .vertical, spacing: 2)
        let stackView = [col0, col1].asStackView(spacing: 12, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 40),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 40),
            stackView.anchorsConstraint(to: self, edgeInsets: edgeInsets),
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: NonFungibleRowViewModelType) {
        backgroundColor = viewModel.contentsBackgroundColor
        titleLabel.text = viewModel.title
        thumbnailImageView.setImage(url: viewModel.imageUrl) 
        descriptionLabel.attributedText = viewModel.attributedDescriptionText
    }

    func configure(tokenHolder: TokenHolder, tokenId: TokenId, tokenView: TokenView, areDetailsVisible: Bool, width: CGFloat, assetDefinitionStore: AssetDefinitionStore) {
        self.tokenView = tokenView
        configure(viewModel: NonFungibleRowViewModel(tokenHolder: tokenHolder, tokenId: tokenId, areDetailsVisible: areDetailsVisible, width: width))
    }
}

protocol NonFungibleRowViewModelType {
    var contentsBackgroundColor: UIColor { get }
    var title: String { get }
    var imageUrl: URL? { get }
    var attributedDescriptionText: NSAttributedString { get }
}
