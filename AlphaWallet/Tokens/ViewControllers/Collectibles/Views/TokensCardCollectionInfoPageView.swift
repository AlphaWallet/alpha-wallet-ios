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

    //FIXME: Replace it
    private var tokenIconImageView: TokenImageView = {
        let imageView = TokenImageView(edgeInsets: .init(top: 20, left: 0, bottom: 0, right: 0))
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
            tokenIconImageView.heightAnchor.constraint(equalToConstant: 250)
        ])

        generateSubviews(viewModel: viewModel)

        let tap = UITapGestureRecognizer(target: self, action: #selector(showContractWebPage))
        tokenIconImageView.addGestureRecognizer(tap)
    }

    private func generateSubviews(viewModel: TokensCardCollectionInfoPageViewModel) {
        stackView.removeAllArrangedSubviews()

        stackView.addArrangedSubview(tokenIconImageView)

        stackView.addArrangedSubview(UIView.spacer(height: 10))
        stackView.addArrangedSubview(UIView.separator())
        stackView.addArrangedSubview(UIView.spacer(height: 10))

        for each in viewModel.configurations {
            switch each {
            case .header(let viewModel):
                let performanceHeader = TokenInfoHeaderView(edgeInsets: .init(top: 15, left: 15, bottom: 20, right: 0))
                performanceHeader.configure(viewModel: viewModel)

                stackView.addArrangedSubview(performanceHeader)
            case .field(let viewModel):
                let field = TokenInstanceAttributeView()
                field.configure(viewModel: viewModel)

                stackView.addArrangedSubview(field)
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
