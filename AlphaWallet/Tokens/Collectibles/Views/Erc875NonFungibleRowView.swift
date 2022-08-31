//
//  Erc875NonFungibleRowView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2021.
//

import UIKit
import AlphaWalletFoundation

class Erc875NonFungibleRowView: TokenCardViewType {
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()

    var positioningView: UIView {
        previewContainerView
    }

    private lazy var previewContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()

    private lazy var tokenCardWebView: TokenCardWebView = {
        return TokenCardWebView(analytics: analytics, server: token.server, tokenView: .viewIconified, assetDefinitionStore: assetDefinitionStore, keystore: keystore, wallet: wallet)
    }()

    private var tokenIconImageView: TokenImageView = {
        let imageView = TokenImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = false
        imageView.rounding = .none
        imageView.isChainOverlayHidden = true
        imageView.contentMode = .scaleAspectFit

        return imageView
    }()

    override var contentMode: UIView.ContentMode {
        didSet { tokenIconImageView.contentMode = contentMode }
    }

    private var imageSmallSizeContraints: [NSLayoutConstraint] = []
    private var imageLargeSizeContraints: [NSLayoutConstraint] = []
    private let tokenType: OpenSeaBackedNonFungibleTokenHandling
    private let analytics: AnalyticsLogger
    private let keystore: Keystore
    private let assetDefinitionStore: AssetDefinitionStore
    private let wallet: Wallet
    private let token: Token

    init(token: Token, tokenType: OpenSeaBackedNonFungibleTokenHandling, analytics: AnalyticsLogger, keystore: Keystore, assetDefinitionStore: AssetDefinitionStore, wallet: Wallet, layout: GridOrListSelectionState, gridEdgeInsets: UIEdgeInsets = .zero, listEdgeInsets: UIEdgeInsets = .init(top: 0, left: 16, bottom: 0, right: 16)) {
        self.gridEdgeInsets = gridEdgeInsets
        self.listEdgeInsets = listEdgeInsets
        self.tokenType = tokenType

        self.analytics = analytics
        self.keystore = keystore
        self.assetDefinitionStore = assetDefinitionStore
        self.wallet = wallet
        self.token = token
        super.init(frame: .zero)

        previewContainerView.addSubview(tokenIconImageView)
        previewContainerView.addSubview(tokenCardWebView)

        titleLabel.baselineAdjustment = .alignCenters
        descriptionLabel.baselineAdjustment = .alignCenters

        imageSmallSizeContraints = previewContainerView.sized(.init(width: 64, height: 64))
        col1.translatesAutoresizingMaskIntoConstraints = false

        switch tokenType {
        case .backedByOpenSea:
            imageLargeSizeContraints = [
                col1.heightAnchor.constraint(equalToConstant: 40),
                previewContainerView.widthAnchor.constraint(equalTo: widthAnchor)
            ]
        case .notBackedByOpenSea:
            imageLargeSizeContraints = [
                previewContainerView.heightAnchor.constraint(equalTo: heightAnchor),
                previewContainerView.widthAnchor.constraint(equalTo: widthAnchor)
            ]
        }

        NSLayoutConstraint.activate([
            tokenIconImageView.anchorsConstraint(to: previewContainerView),
            tokenCardWebView.anchorsConstraint(to: previewContainerView)
        ])

        clipsToBounds = true
        borderColor = R.color.mercury()
        configureLayout(layout: layout)
    }

    private lazy var col0 = previewContainerView
    private lazy var descriptionCo1 = [descriptionLabel, UIView.spacerWidth(flexible: true)].asStackView(axis: .horizontal, spacing: 5)
    private lazy var col1 = [
        [titleLabel, UIView.spacerWidth(flexible: true)].asStackView(axis: .horizontal, spacing: 5),
        descriptionCo1
    ].asStackView(axis: .vertical, spacing: 2)

    private var _constraints: [NSLayoutConstraint] = []
    private var gridEdgeInsets: UIEdgeInsets
    private var listEdgeInsets: UIEdgeInsets

    func configureLayout(layout: GridOrListSelectionState) {
        for each in subviews { each.removeFromSuperview() }
        NSLayoutConstraint.deactivate(_constraints)

        switch layout {
        case .list:
            contentMode = .scaleAspectFit
            borderWidth = 0
            cornerRadius = 0
            col1.alignment = .fill
            descriptionCo1.isHidden = false

            tokenIconImageView.isHidden = false
            tokenCardWebView.isHidden = true

            let stackView = [
                col0,
                col1,
            ].asStackView(axis: .horizontal, spacing: 12, alignment: .center)
            stackView.translatesAutoresizingMaskIntoConstraints = false

            addSubview(stackView)
            _constraints = imageSmallSizeContraints + stackView.anchorsConstraint(to: self, edgeInsets: listEdgeInsets)
        case .grid:
            contentMode = .scaleAspectFill
            cornerRadius = Metrics.CornerRadius.nftBox
            col1.alignment = .center
            descriptionCo1.isHidden = true

            tokenIconImageView.isHidden = true
            tokenCardWebView.isHidden = false

            var subviews: [UIView]
            switch tokenType {
            case .backedByOpenSea:
                borderWidth = 1
                subviews = [
                    col0,
                    .spacer(height: 12),
                    [.spacerWidth(10), col1, .spacerWidth(10)].asStackView(axis: .horizontal),
                    .spacer(height: 16)
                ]
            case .notBackedByOpenSea:
                borderWidth = 0
                subviews = [col0]
            }

            let stackView = subviews.asStackView(axis: .vertical)
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

    private func configure(viewModel: Erc875NonFungibleRowViewModel) {
        backgroundColor = viewModel.contentsBackgroundColor
        titleLabel.text = viewModel.title

        descriptionLabel.font = viewModel.descriptionTextFont
        descriptionLabel.textColor = viewModel.descriptionTextForegroundColor
        descriptionLabel.text = viewModel.descriptionText

        titleLabel.font = viewModel.titleTextFont
        titleLabel.textColor = viewModel.titleTextForegroundColor
        titleLabel.text = viewModel.titleText

        tokenIconImageView.subscribable = token.icon(withSize: .s300)
    }

    func configure(tokenHolder: TokenHolder, tokenId: TokenId) {
        configure(viewModel: Erc875NonFungibleRowViewModel(tokenHolder: tokenHolder, tokenId: tokenId))

        tokenCardWebView.configure(tokenHolder: tokenHolder, tokenId: tokenId)
    }
}
