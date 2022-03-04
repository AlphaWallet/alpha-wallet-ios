//
//  Erc875NonFungibleRowView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2021.
//

import UIKit

//Very similar to NonFungibleRowView below, but keeping around to render FIFA tickets because some attributes are hardcoded
class Erc875NonFungibleRowView: TokenCardViewType {
    var checkboxImageView: UIImageView = UIImageView()
    var stateLabel: UILabel = UILabel()
    var tokenView: TokenView
    var showCheckbox: Bool = false
    var areDetailsVisible: Bool  = false
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
    private var imageSmallSizeContraints: [NSLayoutConstraint] = []
    private var imageLargeSizeContraints: [NSLayoutConstraint] = []

    init(tokenView: TokenView, layout: GridOrListSelectionState, gridEdgeInsets: UIEdgeInsets = .zero, listEdgeInsets: UIEdgeInsets = .init(top: 0, left: 16, bottom: 0, right: 16)) {
        self.tokenView = tokenView
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
        borderColor = R.color.mercury()
        configureLayout(layout: .grid)
    }

    private lazy var col0 = thumbnailImageView
    private lazy var descriptionCo1 = [descriptionLabel, UIView.spacerWidth(flexible: true)].asStackView(axis: .horizontal, spacing: 5)
    private lazy var col1 = [
        [titleLabel, UIView.spacerWidth(flexible: true)].asStackView(axis: .horizontal, spacing: 5),
        descriptionCo1
    ].asStackView(axis: .vertical, spacing: 2)

    private var _constraints: [NSLayoutConstraint] = []
    private var gridEdgeInsets: UIEdgeInsets
    private var listEdgeInsets: UIEdgeInsets

    func configureLayout(layout: GridOrListSelectionState) {
        for each in subviews {
            each.removeFromSuperview()
        }
        NSLayoutConstraint.deactivate(_constraints)

        switch layout {
        case .list:
            _constraints = imageSmallSizeContraints

            borderWidth = 0
            cornerRadius = 0
            col1.alignment = .fill
            descriptionCo1.isHidden = false
            let stackView = [
                col0,
                col1,
            ].asStackView(axis: .horizontal, spacing: 12, alignment: .center)
            stackView.translatesAutoresizingMaskIntoConstraints = false

            addSubview(stackView)
            _constraints = imageSmallSizeContraints + stackView.anchorsConstraint(to: self, edgeInsets: listEdgeInsets)
        case .grid:
            borderWidth = 1
            cornerRadius = Metrics.CornerRadius.nftBox
            col1.alignment = .center
            descriptionCo1.isHidden = true
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

    func configure(viewModel: Erc875NonFungibleRowViewModel) {
        backgroundColor = viewModel.contentsBackgroundColor
        titleLabel.text = viewModel.title
        thumbnailImageView.setImage(url: nil)

        descriptionLabel.font = viewModel.descriptionTextFont
        descriptionLabel.textColor = viewModel.descriptionTextForegroundColor
        descriptionLabel.text = viewModel.descriptionText

        titleLabel.font = viewModel.titleTextFont
        titleLabel.textColor = viewModel.titleTextForegroundColor
        titleLabel.text = viewModel.titleText
    }

    func configure(tokenHolder: TokenHolder, tokenId: TokenId, tokenView: TokenView, areDetailsVisible: Bool, width: CGFloat, assetDefinitionStore: AssetDefinitionStore) {
        self.tokenView = tokenView
        configure(viewModel: Erc875NonFungibleRowViewModel(tokenHolder: tokenHolder, tokenId: tokenId, tokenView: tokenView, assetDefinitionStore: assetDefinitionStore))
    }

}
