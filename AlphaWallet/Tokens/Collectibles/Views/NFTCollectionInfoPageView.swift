//
//  NFTCollectionInfoPageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit
import Combine
import AlphaWalletFoundation

protocol NFTCollectionInfoPageViewDelegate: AnyObject {
    func didPressOpenWebPage(_ url: URL, in view: NFTCollectionInfoPageView)
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, in view: NFTCollectionInfoPageView)
}

//TODO: move to separate view controller like fungible screen does
class NFTCollectionInfoPageView: ScrollableStackView, PageViewType {
    private var previewView: NFTPreviewViewRepresentable
    private let viewModel: NFTCollectionInfoPageViewModel
    private var cancelable = Set<AnyCancellable>()

    weak var delegate: NFTCollectionInfoPageViewDelegate?
    var rightBarButtonItem: UIBarButtonItem?
    var title: String { return viewModel.tabTitle }

    init(viewModel: NFTCollectionInfoPageViewModel,
         session: WalletSession,
         tokenCardViewFactory: TokenCardViewFactory) {

        self.viewModel = viewModel
        self.previewView = tokenCardViewFactory.createPreview(of: viewModel.previewViewType, session: session, edgeInsets: viewModel.previewEdgeInsets)
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

        let tap = UITapGestureRecognizer(target: self, action: #selector(showContractWebPage))
        previewView.addGestureRecognizer(tap)

        bind(viewModel: viewModel)
    }

    private func generateSubviews(for viewTypes: [NFTCollectionInfoPageViewModel.ViewType]) {
        stackView.removeAllArrangedSubviews()

        stackView.addArrangedSubview(UIView.spacer(height: 10))
        stackView.addArrangedSubview(previewView)
        stackView.addArrangedSubview(UIView.spacer(height: 20))

        for (index, each) in viewTypes.enumerated() {
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

    private func bind(viewModel: NFTCollectionInfoPageViewModel) {
        let input = NFTCollectionInfoPageViewModelInput()
        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [weak self, weak previewView] state in
                self?.generateSubviews(for: state.viewTypes)
                previewView?.configure(params: state.previewViewParams)
                previewView?.contentBackgroundColor = state.previewViewContentBackgroundColor
            }.store(in: &cancelable)
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
