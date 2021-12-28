//
//  TokensCardCollectionInfoPageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit

protocol TokensCardCollectionInfoPageViewDelegate: class {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, in view: TokensCardCollectionInfoPageView)
}

class TokensCardCollectionInfoPageView: UIView, PageViewType {
    private let headerViewRefreshInterval: TimeInterval = 5.0

    var title: String {
        return viewModel.tabTitle
    }

    private var tokenIconImageView: TokenImageView = {
        let imageView = TokenImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = true
        return imageView
    }()

    private let containerView = ScrollableStackView()
    private var stackView: UIStackView {
        containerView.stackView
    }

    private (set) var viewModel: TokensCardCollectionInfoPageViewModel
    weak var delegate: TokensCardCollectionInfoPageViewDelegate?
    var rightBarButtonItem: UIBarButtonItem?

    init(viewModel: TokensCardCollectionInfoPageViewModel) {
        self.viewModel = viewModel
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

    private func generateSubviews(viewModel: TokensCardCollectionInfoPageViewModel) {
        stackView.removeAllArrangedSubviews()

        stackView.addArrangedSubview(UIView.spacer(height: 10))
        stackView.addArrangedSubview(tokenIconImageView)

        stackView.addArrangedSubview(UIView.spacer(height: 10))

        for (index, each) in viewModel.configurations.enumerated() {
            switch each {
            case .header(let viewModel):
                let performanceHeader = TokenInfoHeaderView(edgeInsets: .init(top: 15, left: 15, bottom: 20, right: 0))
                performanceHeader.configure(viewModel: viewModel)

                stackView.addArrangedSubview(performanceHeader)
            case .field(let viewModel):
                let view = TokenInstanceAttributeView(indexPath: IndexPath(row: index, section: 0))
                view.configure(viewModel: viewModel)
                view.delegate = self
                stackView.addArrangedSubview(view)
            }
        }
    }

    func configure(viewModel: TokensCardCollectionInfoPageViewModel) {
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

extension TokensCardCollectionInfoPageView: TokenInstanceAttributeViewDelegate {
    func didSelect(in view: TokenInstanceAttributeView) {
        //no-op
    }
}
