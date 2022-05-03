//
//  NFTCollectionInfoPageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit

protocol NFTCollectionInfoPageViewDelegate: class {
    func didPressOpenWebPage(_ url: URL, in view: NFTCollectionInfoPageView)
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, in view: NFTCollectionInfoPageView)
}

class NFTCollectionInfoPageView: UIView, PageViewType {
    private let headerViewRefreshInterval: TimeInterval = 5.0

    var title: String {
        return viewModel.tabTitle
    }

    private var tokenIconImageView: TokenImageView = {
        let imageView = TokenImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = true
        imageView.isRoundingEnabled = false
        imageView.isChainOverlayHidden = true
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let containerView = ScrollableStackView()
    private (set) var viewModel: NFTCollectionInfoPageViewModel
    weak var delegate: NFTCollectionInfoPageViewDelegate?
    var rightBarButtonItem: UIBarButtonItem?
    private let session: WalletSession

    init(viewModel: NFTCollectionInfoPageViewModel, session: WalletSession) {
        self.viewModel = viewModel
        self.session = session
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.anchorsConstraint(to: self),
            tokenIconImageView.heightAnchor.constraint(equalTo: tokenIconImageView.widthAnchor, multiplier: 0.7)
        ])

        generateSubviews(viewModel: viewModel)

        let tap = UITapGestureRecognizer(target: self, action: #selector(showContractWebPage))
        tokenIconImageView.addGestureRecognizer(tap)
    }

    private func generateSubviews(viewModel: NFTCollectionInfoPageViewModel) {
        containerView.stackView.removeAllArrangedSubviews()

        containerView.stackView.addArrangedSubview(UIView.spacer(height: 10))
        containerView.stackView.addArrangedSubview(tokenIconImageView)
        containerView.stackView.addArrangedSubview(UIView.spacer(height: 20))

        for (index, each) in viewModel.configurations.enumerated() {
            switch each {
            case .header(let viewModel):
                let performanceHeader = TokenInfoHeaderView(edgeInsets: .init(top: 15, left: 15, bottom: 20, right: 0))
                performanceHeader.configure(viewModel: viewModel)

                containerView.stackView.addArrangedSubview(performanceHeader)
            case .field(let viewModel):
                let view = TokenInstanceAttributeView(indexPath: IndexPath(row: index, section: 0))
                view.configure(viewModel: viewModel)
                view.delegate = self
                containerView.stackView.addArrangedSubview(view)
            }
        }
    }

    func viewDidLoad() {
        let values = viewModel.tokenHolders[0].values

        if let openSeaSlug = values.slug, openSeaSlug.trimmed.nonEmpty {
            var viewModel = viewModel
            OpenSea.collectionStats(slug: openSeaSlug, server: viewModel.tokenObject.server).done { stats in
                viewModel.configure(overiddenOpenSeaStats: stats)
                self.configure(viewModel: viewModel)
            }.cauterize()
        }
    }

    func configure(viewModel: NFTCollectionInfoPageViewModel) {
        self.viewModel = viewModel

        generateSubviews(viewModel: viewModel)
        tokenIconImageView.subscribable = viewModel.iconImage
    }

    required init?(coder: NSCoder) {
        return nil
    }

    @objc private func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: viewModel.contractAddress, in: self)
    }
}

extension NFTCollectionInfoPageView: TokenInstanceAttributeViewDelegate {
    func didSelect(in view: TokenInstanceAttributeView) {
        let url: URL? = {
            switch viewModel.configurations[view.indexPath.row] {
            case .field(let vm) where viewModel.wikiUrlViewModel == vm:
                return viewModel.wikiUrl
            case .field(let vm) where viewModel.instagramUsernameViewModel == vm:
                return viewModel.instagramUrl
            case .field(let vm) where viewModel.twitterUsernameViewModel == vm:
                return viewModel.twitterUrl
            case .field(let vm) where viewModel.discordUrlViewModel == vm:
                return viewModel.discordUrl
            case .field(let vm) where viewModel.telegramUrlViewModel == vm:
                return viewModel.telegramUrl
            case .field(let vm) where viewModel.externalUrlViewModel == vm:
                return viewModel.externalUrl
            case .header, .field:
                return .none
            }
        }()

        guard let url = url else { return }
        delegate?.didPressOpenWebPage(url, in: self)
    }
}
