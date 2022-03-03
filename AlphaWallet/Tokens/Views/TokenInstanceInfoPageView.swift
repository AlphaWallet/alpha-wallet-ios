//
//  TokenInstanceInfoPageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.12.2021.
//

import UIKit

protocol TokenInstanceInfoPageViewDelegate: class {
    func didSelecAttributeView(attributeView: TokenInstanceAttributeView, in view: TokenInstanceInfoPageView)
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, in view: TokenInstanceInfoPageView)
}

class TokenInstanceInfoPageView: UIView, PageViewType {
    private let headerViewRefreshInterval: TimeInterval = 5.0

    var title: String {
        return viewModel.tabTitle
    }

    private var webImageView: WebImageView = {
        let imageView = WebImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = true
        return imageView
    }()

    private let containerView = ScrollableStackView()
    private var stackView: UIStackView {
        containerView.stackView
    }

    private (set) var viewModel: TokenInstanceInfoPageViewModel
    weak var delegate: TokenInstanceInfoPageViewDelegate?
    var rightBarButtonItem: UIBarButtonItem?

    init(viewModel: TokenInstanceInfoPageViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.anchorsConstraint(to: self),
            webImageView.heightAnchor.constraint(equalTo: webImageView.widthAnchor, multiplier: 0.7)
        ])

        generateSubviews(viewModel: viewModel)

        let tap = UITapGestureRecognizer(target: self, action: #selector(showContractWebPage))
        webImageView.addGestureRecognizer(tap)
    }

    private func generateSubviews(viewModel: TokenInstanceInfoPageViewModel) {
        stackView.removeAllArrangedSubviews()

        stackView.addArrangedSubview(UIView.spacer(height: 10))
        stackView.addArrangedSubview(webImageView)
        stackView.addArrangedSubview(UIView.spacer(height: 20))

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
            case .attributeCollection(let attributes):
                for (row, attribute) in attributes.enumerated() {
                    let view = NonFungibleTraitView(indexPath: IndexPath(row: row, section: index))
                    view.configure(viewModel: attribute)

                    stackView.addArrangedSubview(view)
                }
            }
        }
    }

    func configure(viewModel: TokenInstanceInfoPageViewModel) {
        self.viewModel = viewModel

        generateSubviews(viewModel: viewModel)
        webImageView.setImage(url: viewModel.imageUrl, placeholder: viewModel.tokenImagePlaceholder)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    @objc private func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: viewModel.contractAddress, in: self)
    } 
}

extension TokenInstanceInfoPageView: TokenInstanceAttributeViewDelegate {
    func didSelect(in view: TokenInstanceAttributeView) {
        delegate?.didSelecAttributeView(attributeView: view, in: self)
    }
}
