//
//  TokenCardRedemptionViewController.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/6/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit
import AlphaWalletFoundation

protocol TokenCardRedemptionViewControllerDelegate: AnyObject, CanOpenURL {
}

class TokenCardRedemptionViewController: UIViewController, TokenVerifiableStatusViewController {
    private var viewModel: TokenCardRedemptionViewModel
    private let containerView = ScrollableStackView()
    private let imageView = UIImageView()
    private let tokenRowView: TokenRowView & UIView

    var contract: AlphaWallet.Address {
        return viewModel.token.contractAddress
    }
    var server: RPCServer {
        return viewModel.token.server
    }
    let assetDefinitionStore: AssetDefinitionStore
    weak var delegate: TokenCardRedemptionViewControllerDelegate?

    init(viewModel: TokenCardRedemptionViewModel,
         assetDefinitionStore: AssetDefinitionStore) {

        self.viewModel = viewModel
        self.assetDefinitionStore = assetDefinitionStore

        let tokenType = OpenSeaBackedNonFungibleTokenHandling(token: viewModel.token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified)
        switch tokenType {
        case .backedByOpenSea:
            tokenRowView = OpenSeaNonFungibleTokenCardRowView(tokenView: .viewIconified)
        case .notBackedByOpenSea:
            tokenRowView = TokenCardRowView(
                server: viewModel.token.server,
                tokenView: .viewIconified,
                assetDefinitionStore: assetDefinitionStore,
                wallet: viewModel.session.account)
        }

        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(withTokenScriptFileStatus: nil)

        imageView.translatesAutoresizingMaskIntoConstraints = false

        let imageHolder = UIView()
        imageHolder.translatesAutoresizingMaskIntoConstraints = false
        imageHolder.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        imageHolder.cornerRadius = DataEntry.Metric.CornerRadius.box
        imageHolder.addSubview(imageView)

        tokenRowView.translatesAutoresizingMaskIntoConstraints = false

        containerView.stackView.addArrangedSubviews([
            .spacer(height: 18),
            imageHolder,
            .spacer(height: 4),
            tokenRowView,
        ])
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: imageHolder.leadingAnchor, constant: 64),
            imageView.trailingAnchor.constraint(equalTo: imageHolder.trailingAnchor, constant: -64),
            imageView.topAnchor.constraint(equalTo: imageHolder.topAnchor, constant: 16),
            imageView.bottomAnchor.constraint(equalTo: imageHolder.bottomAnchor, constant: -16),
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor),

            imageHolder.leadingAnchor.constraint(equalTo: tokenRowView.background.leadingAnchor),
            imageHolder.trailingAnchor.constraint(equalTo: tokenRowView.background.trailingAnchor),

            tokenRowView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tokenRowView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            containerView.anchorsIgnoringBottomSafeArea(to: view)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel newViewModel: TokenCardRedemptionViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)

        navigationItem.title = viewModel.headerTitle

        //TODO async-await: This could cause timing issues since we might finish the async call later
        Task {
            imageView.image = await viewModel.redeemQrCode()
        }

        tokenRowView.configure(tokenHolder: viewModel.tokenHolder)

        tokenRowView.stateLabel.isHidden = true
    }
}

extension TokenCardRedemptionViewController: VerifiableStatusViewController {
    func showInfo() {
        let controller = TokenCardRedemptionInfoViewController(delegate: self)
        controller.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(controller, animated: true)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: viewModel.token.contractAddress, server: server, in: self)
    }

    func open(url: URL) {
        delegate?.didPressViewContractWebPage(url, in: self)
    }
}

extension TokenCardRedemptionViewController: StaticHTMLViewControllerDelegate {
}

extension TokenCardRedemptionViewController: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}
