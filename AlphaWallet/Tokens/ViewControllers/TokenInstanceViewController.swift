//
//  TokenInstanceViewController2.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit

protocol TokenInstanceViewControllerDelegate: class, CanOpenURL {
    func didPressRedeem(token: TokenObject, tokenHolder: TokenHolder, in viewController: TokenInstanceViewController)
    func didPressSell(tokenHolder: TokenHolder, for paymentFlow: PaymentFlow, in viewController: TokenInstanceViewController)
    func didPressTransfer(token: TokenObject, tokenHolder: TokenHolder, forPaymentFlow paymentFlow: PaymentFlow, in viewController: TokenInstanceViewController)
    func didPressViewRedemptionInfo(in viewController: TokenInstanceViewController)
    func didTapURL(url: URL, in viewController: TokenInstanceViewController)
    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: TokenInstanceViewController)
}

class TokenInstanceViewController: UIViewController, TokenVerifiableStatusViewController {
    private let analyticsCoordinator: AnalyticsCoordinator
    private let tokenObject: TokenObject
    private var viewModel: TokenInstanceViewModel
    private let account: Wallet
    private let bigImageView = WebImageView()
    private let buttonsBar = ButtonsBar(configuration: .combined(buttons: 3))

    var tokenHolder: TokenHolder {
        return viewModel.tokenHolder
    }
    var server: RPCServer {
        return tokenObject.server
    }
    var contract: AlphaWallet.Address {
        return tokenObject.contractAddress
    }
    let assetDefinitionStore: AssetDefinitionStore
    weak var delegate: TokenInstanceViewControllerDelegate?

    private lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        return view
    }()
    private let mode: TokenInstanceViewMode

    init(analyticsCoordinator: AnalyticsCoordinator, tokenObject: TokenObject, tokenHolder: TokenHolder, tokenId: TokenId, account: Wallet, assetDefinitionStore: AssetDefinitionStore, mode: TokenInstanceViewMode) {
        self.analyticsCoordinator = analyticsCoordinator
        self.tokenObject = tokenObject
        self.account = account
        self.assetDefinitionStore = assetDefinitionStore
        self.mode = mode
        self.viewModel = .init(tokenId: tokenId, token: tokenObject, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        super.init(nibName: nil, bundle: nil)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
        let stackView = [containerView, footerBar].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: view),
            bigImageView.heightAnchor.constraint(equalToConstant: 250),
        ])

        configure(viewModel: viewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    //NOTE: Blank out the title before pushing the send screen because longer (not even very long ones) titles will overlay the Send screen's back button
    override func viewWillAppear(_ animated: Bool) {
        title = viewModel.navigationTitle
        super.viewWillAppear(animated)
        hideNavigationBarTopSeparatorLine()
    }

    override func viewWillDisappear(_ animated: Bool) {
        title = ""
        super.viewWillDisappear(animated)
        showNavigationBarTopSeparatorLine()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let values = viewModel.tokenHolder.values
        if let openSeaSlug = values.slug, openSeaSlug.trimmed.nonEmpty {
            var viewModel = viewModel
            OpenSea.collectionStats(slug: openSeaSlug).done { stats in
                viewModel.configure(overiddenOpenSeaStats: stats)
                self.configure(viewModel: viewModel)
            }.cauterize()
        }
    }

    private func generateSubviews(viewModel: TokenInstanceViewModel) {
        let stackView = containerView.stackView
        stackView.removeAllArrangedSubviews()

        var subviews: [UIView] = [bigImageView]

        for (index, each) in viewModel.configurations.enumerated() {
            switch each {
            case .header(let viewModel):
                let header = TokenInfoHeaderView(edgeInsets: .init(top: 15, left: 15, bottom: 20, right: 0))
                header.configure(viewModel: viewModel)

                subviews.append(header)
            case .field(let viewModel):
                let view = TokenInstanceAttributeView(indexPath: IndexPath(row: index, section: 0))
                view.configure(viewModel: viewModel)
                view.delegate = self

                subviews.append(view)
            case .attributeCollection(let attributes):
                for (row, attribute) in attributes.enumerated() {
                    let view = NonFungibleTraitView(indexPath: IndexPath(row: row, section: index))
                    view.configure(viewModel: attribute)

                    subviews.append(view)
                }
            }
        }

        stackView.addArrangedSubviews(subviews)
    }

    func configure(viewModel newViewModel: TokenInstanceViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }

        view.backgroundColor = viewModel.backgroundColor
        containerView.backgroundColor = viewModel.backgroundColor
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)
        title = viewModel.navigationTitle

        switch mode {
        case .preview:
            buttonsBar.configure(.empty)
        case .interactive:
            buttonsBar.configure(.combined(buttons: viewModel.actions.count))
            buttonsBar.viewController = self

            func _configButton(action: TokenInstanceAction, button: BarButton) {
                if let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: account.address) {
                    if selection.denial == nil {
                        button.displayButton = false
                    }
                }
            }

            for (index, button) in buttonsBar.buttons.enumerated() {
                let action = viewModel.actions[index]
                button.setTitle(action.name, for: .normal)
                button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
                switch account.type {
                case .real:
                    _configButton(action: action, button: button)
                case .watch:
                    //TODO pass in a Config instance instead
                    if Config().development.shouldPretendIsRealWallet {
                        _configButton(action: action, button: button)
                    } else {
                        button.isEnabled = false
                    }
                }
            }
        }

        bigImageView.setImage(url: tokenHolder.assetImageUrl(tokenId: viewModel.tokenId), placeholder: viewModel.tokenImagePlaceholder)

        generateSubviews(viewModel: viewModel)
    }

    func firstMatchingTokenHolder(fromTokenHolders tokenHolders: [TokenHolder]) -> TokenHolder? {
        return tokenHolders.first { $0.tokens[0].id == viewModel.tokenId }
    }

    func isMatchingTokenHolder(fromTokenHolders tokenHolders: [TokenHolder]) -> (tokenHolder: TokenHolder, tokenId: TokenId)? {
        return tokenHolders.first(where: { $0.tokens.contains(where: { $0.id == viewModel.tokenId }) }).flatMap { ($0, viewModel.tokenId) }
    }

    @objc private func actionButtonTapped(sender: UIButton) {
        let actions = viewModel.actions
        for (action, button) in zip(actions, buttonsBar.buttons) where button == sender {
            switch action.type {
            case .nftRedeem:
                redeem()
            case .nftSell:
                sell()
            case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
                //TODO when we support TokenScript views for ERC20s, we need to perform the action here
                break
            case .nonFungibleTransfer:
                transfer()
            case .tokenScript:
                if let selection = action.activeExcludingSelection(selectedTokenHolder: tokenHolder, tokenId: viewModel.tokenId, forWalletAddress: account.address) {
                    if let denialMessage = selection.denial {
                        UIAlertController.alert(
                                title: nil,
                                message: denialMessage,
                                alertButtonTitles: [R.string.localizable.oK()],
                                alertButtonStyles: [.default],
                                viewController: self,
                                completion: nil
                        )
                    } else {
                        //no-op shouldn't have reached here since the button should be disabled. So just do nothing to be safe
                    }
                } else {
                    delegate?.didTap(action: action, tokenHolder: tokenHolder, viewController: self)
                }
            }
            break
        }
    }

    private func transfer() {
        tokenHolder.select(with: .allFor(tokenId: tokenHolder.tokenId))
        let transactionType = TransactionType(nonFungibleToken: tokenObject, tokenHolders: [tokenHolder])

        delegate?.didPressTransfer(token: tokenObject, tokenHolder: tokenHolder, forPaymentFlow: .send(type: .transaction(transactionType)), in: self)
    }

    private func redeem() {
        delegate?.didPressRedeem(token: viewModel.token, tokenHolder: viewModel.tokenHolder, in: self)
    }

    private func sell() {
        tokenHolder.select(with: .allFor(tokenId: tokenHolder.tokenId))
        let transactionType = TransactionType.erc875Token(viewModel.token, tokenHolders: [tokenHolder])

        delegate?.didPressSell(tokenHolder: tokenHolder, for: .send(type: .transaction(transactionType)), in: self)
    }
}

extension TokenInstanceViewController: VerifiableStatusViewController {
    func showInfo() {
        delegate?.didPressViewRedemptionInfo(in: self)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: tokenObject.contractAddress, server: server, in: self)
    }

    func open(url: URL) {
        delegate?.didPressViewContractWebPage(url, in: self)
    }
}

extension TokenInstanceViewController: TokenInstanceAttributeViewDelegate {
    func didSelect(in view: TokenInstanceAttributeView) {
        switch viewModel.configurations[view.indexPath.row] {
        case .field(let vm) where viewModel.tokenIdViewModel == vm:
            UIPasteboard.general.string = vm.value

            self.view.showCopiedToClipboard(title: R.string.localizable.copiedToClipboard())
        case .field(let vm) where viewModel.creatorViewModel == vm:
            guard let url = viewModel.creatorOnOpenSeaUrl else { return }
            
            delegate?.didPressViewContractWebPage(url, in: self)
        case .field(let vm) where viewModel.contractViewModel == vm:
            guard let url = viewModel.contractOnExplorerUrl else { return }

            delegate?.didPressViewContractWebPage(url, in: self)
        case .header, .field, .attributeCollection:
            break
        }
    }
}
