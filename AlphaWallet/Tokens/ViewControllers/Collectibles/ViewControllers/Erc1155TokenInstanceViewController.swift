//
//  TokenInstanceViewController2.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit

protocol Erc1155TokenInstanceViewControllerDelegate: class, CanOpenURL {
    func didPressRedeem(token: TokenObject, tokenHolder: TokenHolder, in viewController: Erc1155TokenInstanceViewController)
    func didPressSell(tokenHolder: TokenHolder, for paymentFlow: PaymentFlow, in viewController: Erc1155TokenInstanceViewController)
    func didPressTransfer(token: TokenObject, tokenHolder: TokenHolder, forPaymentFlow paymentFlow: PaymentFlow, in viewController: Erc1155TokenInstanceViewController)
    func didPressViewRedemptionInfo(in viewController: Erc1155TokenInstanceViewController)
    func didTapURL(url: URL, in viewController: Erc1155TokenInstanceViewController)
    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: Erc1155TokenInstanceViewController)
}

class Erc1155TokenInstanceViewController: UIViewController, TokenVerifiableStatusViewController {
    private let analyticsCoordinator: AnalyticsCoordinator
    private let tokenObject: TokenObject
    private var viewModel: Erc1155TokenInstanceViewModel
    private let account: Wallet
    private let bigImageView = WebImageView(type: .original)
    lazy private var bigImageHolderHeightConstraint = bigImageView.heightAnchor.constraint(equalToConstant: 300)

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
    weak var delegate: Erc1155TokenInstanceViewControllerDelegate?

    var isReadOnly = false {
        didSet {
            configure()
        }
    }

    var canPeekToken: Bool {
        switch NonFungibleFromJsonSupportedTokenHandling(token: tokenObject) {
        case .supported:
            return true
        case .notSupported:
            return false
        }
    }

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
            bigImageHolderHeightConstraint,
        ])

        configure(viewModel: viewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    //Blank out the title before pushing the send screen because longer (not even very long ones) titles will overlay the Send screen's back button
    override func viewWillAppear(_ animated: Bool) {
        title = viewModel.navigationTitle
        super.viewWillAppear(animated)
    }
    override func viewWillDisappear(_ animated: Bool) {
        title = ""
        super.viewWillDisappear(animated)
    }

    private func generateSubviews(viewModel: Erc1155TokenInstanceViewModel) {
        let stackView = containerView.stackView
        stackView.removeAllArrangedSubviews()

        bigImageView.contentMode = .scaleAspectFit
        bigImageView.backgroundColor = .clear
        bigImageView.clipsToBounds = true
        var subviews: [UIView] = [bigImageView]

        for each in viewModel.configurations {
            switch each {
            case .header(let viewModel):
                let header = TokenInfoHeaderView(edgeInsets: .init(top: 15, left: 15, bottom: 20, right: 0))
                header.configure(viewModel: viewModel)

                subviews.append(header)
            case .field(let viewModel):
                let view = TokenInstanceAttributeView()
                view.configure(viewModel: viewModel)

                subviews.append(view)
            }
        }

        stackView.addArrangedSubviews(subviews)
    }

    func configure(viewModel newViewModel: Erc1155TokenInstanceViewModel? = nil) {
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

            for (index, button) in buttonsBar.buttons.enumerated() {
                let action = viewModel.actions[index]
                button.setTitle(action.name, for: .normal)
                button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
            }
        }

        if let url = tokenHolder.values.imageUrlUrlValue {
            bigImageView.url = url
            bigImageHolderHeightConstraint.constant = 300
        } else if let url = tokenHolder.values.thumbnailUrlUrlValue {
            bigImageView.url = url
            bigImageHolderHeightConstraint.constant = 300
        } else {
            bigImageHolderHeightConstraint.constant = 0
        }

        generateSubviews(viewModel: viewModel)
    }

    func isMatchingTokenHolder(fromTokenHolders tokenHolders: [TokenHolder]) -> (tokenHolder: TokenHolder, tokenId: TokenId)? {
        return tokenHolders.first(where: { $0.tokens.contains(where: { $0.id == viewModel.tokenId }) }).flatMap { ($0, viewModel.tokenId) }
    }

    private func redeem() {
        delegate?.didPressRedeem(token: tokenObject, tokenHolder: tokenHolder, in: self)
    }

    private func sell() {
        delegate?.didPressSell(tokenHolder: tokenHolder, for: .send(type: .erc875Token(tokenObject)), in: self)
    }

    private func transfer() {
        let transactionType = TransactionType(token: tokenObject)
        delegate?.didPressTransfer(token: tokenObject, tokenHolder: tokenHolder, forPaymentFlow: .send(type: transactionType), in: self)
    }

    @objc private func actionButtonTapped(sender: UIButton) {
        let actions = viewModel.actions
        for (action, button) in zip(actions, buttonsBar.buttons) where button == sender {
            switch action.type {
            case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
                //TODO when we support TokenScript views for ERC20s, we need to perform the action here
                break
            case .nftRedeem:
                redeem()
            case .nftSell:
                sell()
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
}

extension Erc1155TokenInstanceViewController: VerifiableStatusViewController {
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

extension Erc1155TokenInstanceViewController: BaseTokenCardTableViewCellDelegate {
    func didTapURL(url: URL) {
        delegate?.didPressOpenWebPage(url, in: self)
    }
}

extension Erc1155TokenInstanceViewController: TokenCardsViewControllerHeaderDelegate {
    func didPressViewContractWebPage(inHeaderView: TokenCardsViewControllerHeader) {
        showContractWebPage()
    }
}

extension Erc1155TokenInstanceViewController: OpenSeaNonFungibleTokenCardRowViewDelegate {
    //Implemented as part of implementing BaseOpenSeaNonFungibleTokenCardTableViewCellDelegate
//    func didTapURL(url: URL) {
//        delegate?.didPressOpenWebPage(url, in: self)
//    }
}
