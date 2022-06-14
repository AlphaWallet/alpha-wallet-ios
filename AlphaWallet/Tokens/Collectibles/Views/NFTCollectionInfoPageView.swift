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

class NFTCollectionInfoPageView: ScrollableStackView, PageViewType {
    private let previewView: NFTPreviewView
    private (set) var viewModel: NFTCollectionInfoPageViewModel
    private let openSea: OpenSea

    weak var delegate: NFTCollectionInfoPageViewDelegate?
    var rightBarButtonItem: UIBarButtonItem?
    var title: String { return viewModel.tabTitle }

    init(viewModel: NFTCollectionInfoPageViewModel, openSea: OpenSea, keystore: Keystore, session: WalletSession, assetDefinitionStore: AssetDefinitionStore, analyticsCoordinator: AnalyticsCoordinator) {
        self.viewModel = viewModel
        self.openSea = openSea
        self.previewView = .init(type: viewModel.previewViewType, keystore: keystore, session: session, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, edgeInsets: viewModel.previewEdgeInsets)
        self.previewView.rounding = .custom(20)
        self.previewView.contentMode = .scaleAspectFill
        super.init()

        translatesAutoresizingMaskIntoConstraints = false

        let previewHeightConstraint: [NSLayoutConstraint]
        switch viewModel.previewViewType {
        case .imageView:
            previewHeightConstraint = [previewView.heightAnchor.constraint(equalTo: previewView.widthAnchor)]
        case .tokenCardView:
            previewHeightConstraint = []
        }

        NSLayoutConstraint.activate([previewHeightConstraint])

        generateSubviews(viewModel: viewModel)

        let tap = UITapGestureRecognizer(target: self, action: #selector(showContractWebPage))
        previewView.addGestureRecognizer(tap)
    }

    private func generateSubviews(viewModel: NFTCollectionInfoPageViewModel) {
        stackView.removeAllArrangedSubviews()

        stackView.addArrangedSubview(UIView.spacer(height: 10))
        stackView.addArrangedSubview(previewView)
        stackView.addArrangedSubview(UIView.spacer(height: 20))

        for (index, each) in viewModel.configurations.enumerated() {
            switch each {
            case .header(let viewModel):
                let performanceHeader = TokenInfoHeaderView(edgeInsets: .init(top: 15, left: 15, bottom: 20, right: 0))
                performanceHeader.configure(viewModel: viewModel)

                stackView.addArrangedSubview(performanceHeader)
            case .field(let viewModel):
                let view = TokenAttributeView(indexPath: IndexPath(row: index, section: 0))
                view.configure(viewModel: viewModel)
                view.delegate = self
                stackView.addArrangedSubview(view)
            }
        }
    }

    func viewDidLoad() {
        let values = viewModel.tokenHolders[0].values

        if let openSeaSlug = values.slug, openSeaSlug.trimmed.nonEmpty {
            var viewModel = viewModel
            openSea.collectionStats(slug: openSeaSlug, server: viewModel.token.server).done { stats in
                viewModel.configure(overiddenOpenSeaStats: stats)
                self.configure(viewModel: viewModel)
            }.cauterize()
        }
    }

    func configure(viewModel: NFTCollectionInfoPageViewModel) {
        self.viewModel = viewModel

        generateSubviews(viewModel: viewModel)
        previewView.configure(params: viewModel.previewViewParams)
        previewView.contentBackgroundColor = viewModel.previewViewContentBackgroundColor
    }

    required init?(coder: NSCoder) {
        return nil
    }

    @objc private func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: viewModel.contractAddress, in: self)
    }
}

extension NFTCollectionInfoPageView: TokenAttributeViewDelegate {
    func didSelect(in view: TokenAttributeView) {
        guard let url = viewModel.urlForField(indexPath: view.indexPath) else { return }
        delegate?.didPressOpenWebPage(url, in: self)
    }
}
