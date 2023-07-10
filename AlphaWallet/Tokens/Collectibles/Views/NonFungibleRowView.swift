//
//  NonFungibleRowView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.11.2021.
//

import UIKit
import AlphaWalletFoundation
import struct AlphaWalletTokenScript.TokenId

class NonFungibleRowView: TokenCardViewRepresentable {
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()

    var positioningView: UIView {
        thumbnailImageView
    }

    private var thumbnailImageView: TokenImageView = {
        let imageView = TokenImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = true
        imageView.rounding = .none
        imageView.isChainOverlayHidden = true
        imageView.contentMode = .scaleAspectFill
        imageView.loading = .disabled

        return imageView
    }()

    private var imageSmallSizeContraints: [NSLayoutConstraint] = []
    private var imageLargeSizeContraints: [NSLayoutConstraint] = []

    private lazy var col0 = thumbnailImageView
    private lazy var col1 = [
        [titleLabel, UIView.spacerWidth(flexible: true)].asStackView(axis: .horizontal, spacing: 5),
        [descriptionLabel, UIView.spacerWidth(flexible: true)].asStackView(axis: .horizontal, spacing: 5)
    ].asStackView(axis: .vertical, spacing: 2)

    private var _constraints: [NSLayoutConstraint] = []
    private var gridEdgeInsets: UIEdgeInsets
    private var listEdgeInsets: UIEdgeInsets

    init(layout: GridOrListLayout, gridEdgeInsets: UIEdgeInsets = .zero, listEdgeInsets: UIEdgeInsets = .init(top: 0, left: 16, bottom: 0, right: 16)) {
        self.gridEdgeInsets = gridEdgeInsets
        self.listEdgeInsets = listEdgeInsets
        super.init(frame: .zero)

        titleLabel.baselineAdjustment = .alignCenters
        descriptionLabel.baselineAdjustment = .alignCenters

        imageSmallSizeContraints = thumbnailImageView.sized(.init(width: 64, height: 64))
        col1.translatesAutoresizingMaskIntoConstraints = false
        imageLargeSizeContraints = [
            col1.heightAnchor.constraint(equalToConstant: 40),
            thumbnailImageView.widthAnchor.constraint(equalTo: widthAnchor)
        ]

        clipsToBounds = true
        backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        borderColor = Configuration.Color.Semantic.tableViewSeparator
        configureLayout(layout: layout)
    }

    func configureLayout(layout: GridOrListLayout) {
        for each in subviews { each.removeFromSuperview() }
        NSLayoutConstraint.deactivate(_constraints)

        switch layout {
        case .list:
            borderWidth = 0
            cornerRadius = 0
            col1.alignment = .fill
            thumbnailImageView.rounding = .custom(8)

            let stackView = [
                col0,
                col1,
            ].asStackView(axis: .horizontal, spacing: 12, alignment: .center)
            stackView.translatesAutoresizingMaskIntoConstraints = false

            addSubview(stackView)
            _constraints = imageSmallSizeContraints + stackView.anchorsConstraint(to: self, edgeInsets: listEdgeInsets)
        case .grid:
            borderWidth = 1
            cornerRadius = DataEntry.Metric.CornerRadius.nftBox
            col1.alignment = .center
            thumbnailImageView.rounding = .none

            let stackView = [
                col0,
                .spacer(height: 12),
                [.spacerWidth(10), col1, .spacerWidth(10)].asStackView(axis: .horizontal),
                .spacer(height: 16)
            ].asStackView(axis: .vertical)
            stackView.translatesAutoresizingMaskIntoConstraints = false

            addSubview(stackView)
            _constraints = imageLargeSizeContraints + stackView.anchorsConstraint(to: self, edgeInsets: gridEdgeInsets)
        }

        NSLayoutConstraint.activate(_constraints)
        updateConstraintsIfNeeded()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: NonFungibleRowViewModel) {
        thumbnailImageView.contentBackgroundColor = viewModel.contentBackgroundColor
        thumbnailImageView.set(imageSource: viewModel.assetImage)
        descriptionLabel.attributedText = viewModel.description
        titleLabel.attributedText = viewModel.title
    }

    func configure(tokenHolder: TokenHolder, tokenId: TokenId) {
        configure(viewModel: NonFungibleRowViewModel(tokenHolder: tokenHolder, tokenId: tokenId))
    }
}
