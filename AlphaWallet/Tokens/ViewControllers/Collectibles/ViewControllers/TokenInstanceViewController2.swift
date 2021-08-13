//
//  TokenInstanceViewController2.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit

protocol TokenInstanceViewControllerDelegate2: class, CanOpenURL {
    func didPressRedeem(token: TokenObject, tokenHolder: TokenHolder, in viewController: TokenInstanceViewController2)
    func didPressSell(tokenHolder: TokenHolder, for paymentFlow: PaymentFlow, in viewController: TokenInstanceViewController2)
//    func didPressGenerateMagicLink(tokenHolder: TokenHolder, for paymentFlow: PaymentFlow, in viewController: TokenInstanceViewController2)
    func didPressTransfer(token: TokenObject, tokenHolder: TokenHolder, forPaymentFlow paymentFlow: PaymentFlow, in viewController: TokenInstanceViewController2)
    func didPressViewRedemptionInfo(in viewController: TokenInstanceViewController2)
    func didTapURL(url: URL, in viewController: TokenInstanceViewController2)
    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: TokenInstanceViewController2)
}

class TokenInstanceViewController2: UIViewController, TokenVerifiableStatusViewController {
    private let analyticsCoordinator: AnalyticsCoordinator
    private let tokenObject: TokenObject
    private var viewModel: TokenInstanceViewModel2
    private let account: Wallet
    private lazy var tokenRowView: TokenCardRowViewProtocol & UIView = createTokenRowView()

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
    weak var delegate: TokenInstanceViewControllerDelegate2?

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

        NSLayoutConstraint.activate([stackView.anchorsConstraint(to: view)])

        configure(viewModel: viewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func generateSubviews(viewModel: TokenInstanceViewModel2) {
        let stackView = containerView.stackView
        stackView.removeAllArrangedSubviews()

        var subviews: [UIView] = [tokenRowView]

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

    func configure(viewModel newViewModel: TokenInstanceViewModel2? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }

        view.backgroundColor = viewModel.backgroundColor
        containerView.backgroundColor = viewModel.backgroundColor
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)

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
    //            switch account.type {
    //            case .real:
    //                if let selection = action.activeExcludingSelection(selectedTokenHolder: tokenHolder, tokenId: viewModel.tokenId, forWalletAddress: account.address) {
    //                    if selection.denial == nil {
    //                        button.displayButton = false
    //                    }
    //                }
    //            case .watch:
    //                button.isEnabled = false
    //            }
            }
        }

        tokenRowView.configure(tokenHolder: tokenHolder, tokenId: viewModel.tokenId, tokenView: .view, areDetailsVisible: tokenHolder.areDetailsVisible, width: 0, assetDefinitionStore: assetDefinitionStore)

        generateSubviews(viewModel: viewModel)
    }

    func isMatchingTokenHolder(fromTokenHolders tokenHolders: [TokenHolder]) -> (tokenHolder: TokenHolder, tokenId: TokenId)? {
        return tokenHolders.first(where: { $0.tokens.contains(where: { $0.id == viewModel.tokenId }) }).flatMap { ($0, viewModel.tokenId) }
    }

    func redeem() {
        delegate?.didPressRedeem(token: tokenObject, tokenHolder: tokenHolder, in: self)
    }

    func sell() {
        delegate?.didPressSell(tokenHolder: tokenHolder, for: .send(type: .ERC875Token(tokenObject)), in: self)
    }

    func transfer() {
        let transactionType = TransactionType(token: tokenObject)
        delegate?.didPressTransfer(token: tokenObject, tokenHolder: tokenHolder, forPaymentFlow: .send(type: transactionType), in: self)
    }

    @objc func actionButtonTapped(sender: UIButton) {
        let actions = viewModel.actions
        for (action, button) in zip(actions, buttonsBar.buttons) where button == sender {
            switch action.type {
            case .erc20Send, .erc20Receive, .swap, .xDaiBridge, .buy:
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

    private func createTokenRowView() -> TokenCardRowViewProtocol & UIView {
        let tokenType = OpenSeaBackedNonFungibleTokenHandling(token: tokenObject, assetDefinitionStore: assetDefinitionStore, tokenViewType: .view)
        let rowView: TokenCardRowViewProtocol & UIView
        switch tokenType {
        case .backedByOpenSea:
            rowView = {
                let rowView = OpenSeaNonFungibleTokenCardRowView(tokenView: .view, showCheckbox: false)
                rowView.delegate = self

                let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tappedOpenSeaTokenCardRowView))
                rowView.addGestureRecognizer(tapGestureRecognizer)

                return rowView
            }()
        case .notBackedByOpenSea:
            rowView = {
                let view = TokenCardRowView(analyticsCoordinator: analyticsCoordinator, server: server, tokenView: .view, showCheckbox: false, assetDefinitionStore: assetDefinitionStore)
                view.isStandalone = true
                view.tokenScriptRendererView.isWebViewInteractionEnabled = true
                return view
            }()
        }
        return rowView
    }

    @objc private func tappedOpenSeaTokenCardRowView() {
        //We don't allow user to toggle (despite it not doing anything) for non-opensea-backed tokens because it will cause TokenScript views to flash as they have to be re-rendered
        switch OpenSeaBackedNonFungibleTokenHandling(token: viewModel.token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .view) {
        case .backedByOpenSea:
            viewModel.toggleSelection(for: .init(row: 0, section: 0))
            configure()
        case .notBackedByOpenSea:
            break
        }
    }
}

extension TokenInstanceViewController2: VerifiableStatusViewController {
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

extension TokenInstanceViewController2: BaseTokenCardTableViewCellDelegate {
    func didTapURL(url: URL) {
        delegate?.didPressOpenWebPage(url, in: self)
    }
}

extension TokenInstanceViewController2: TokenCardsViewControllerHeaderDelegate {
    func didPressViewContractWebPage(inHeaderView: TokenCardsViewControllerHeader) {
        showContractWebPage()
    }
}

extension TokenInstanceViewController2: OpenSeaNonFungibleTokenCardRowViewDelegate {
    //Implemented as part of implementing BaseOpenSeaNonFungibleTokenCardTableViewCellDelegate
//    func didTapURL(url: URL) {
//        delegate?.didPressOpenWebPage(url, in: self)
//    }
}
