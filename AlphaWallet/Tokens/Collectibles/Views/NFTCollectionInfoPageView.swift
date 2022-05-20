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
    private let previewView: NFTPreviewView
    private let containerView = ScrollableStackView()
    private (set) var viewModel: NFTCollectionInfoPageViewModel

    weak var delegate: NFTCollectionInfoPageViewDelegate?
    var rightBarButtonItem: UIBarButtonItem?
    var title: String { return viewModel.tabTitle }

    init(viewModel: NFTCollectionInfoPageViewModel, keystore: Keystore, session: WalletSession, assetDefinitionStore: AssetDefinitionStore, analyticsCoordinator: AnalyticsCoordinator) {
        self.viewModel = viewModel
        self.previewView = .init(type: viewModel.previewViewType, keystore: keystore, session: session, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, edgeInsets: viewModel.previewEdgeInsets)
        self.previewView.rounding = .custom(20)
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        addSubview(containerView)

        let previewHeightConstraint: [NSLayoutConstraint]
        switch viewModel.previewViewType {
        case .imageView:
            previewHeightConstraint = [previewView.heightAnchor.constraint(equalTo: previewView.widthAnchor, multiplier: 0.7)]
        case .tokenCardView:
            previewHeightConstraint = []
        }

        NSLayoutConstraint.activate([
            containerView.anchorsConstraint(to: self),
        ] + previewHeightConstraint)

        generateSubviews(viewModel: viewModel)

        let tap = UITapGestureRecognizer(target: self, action: #selector(showContractWebPage))
        previewView.addGestureRecognizer(tap)
    }

    private func generateSubviews(viewModel: NFTCollectionInfoPageViewModel) {
        containerView.stackView.removeAllArrangedSubviews()

        containerView.stackView.addArrangedSubview(UIView.spacer(height: 10))
        containerView.stackView.addArrangedSubview(previewView)
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
            OpenSea.collectionStats(slug: openSeaSlug, server: viewModel.token.server).done { stats in
                viewModel.configure(overiddenOpenSeaStats: stats)
                self.configure(viewModel: viewModel)
            }.cauterize()
        }
    }

    func configure(viewModel: NFTCollectionInfoPageViewModel) {
        self.viewModel = viewModel

        generateSubviews(viewModel: viewModel)
        previewView.configure(params: viewModel.previewViewParams)
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
        guard let url = viewModel.urlForField(indexPath: view.indexPath) else { return }
        delegate?.didPressOpenWebPage(url, in: self)
    }
}
