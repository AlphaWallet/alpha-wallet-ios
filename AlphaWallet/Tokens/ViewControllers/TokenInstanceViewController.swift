// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol TokenInstanceViewControllerDelegate: class, CanOpenURL {
    func didPressRedeem(token: TokenObject, tokenHolder: TokenHolder, in viewController: TokenInstanceViewController)
    func didPressSell(tokenHolder: TokenHolder, for paymentFlow: PaymentFlow, in viewController: TokenInstanceViewController)
    func didPressTransfer(token: TokenObject, tokenHolder: TokenHolder, forPaymentFlow paymentFlow: PaymentFlow, in viewController: TokenInstanceViewController)
    func didPressViewRedemptionInfo(in viewController: TokenInstanceViewController)
    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: TokenInstanceViewController)
    func didTap(activity: Activity, in viewController: TokenInstanceViewController)
    func didTap(transaction: TransactionInstance, in viewController: TokenInstanceViewController)
}

class TokenInstanceViewController: UIViewController {
    private (set) var viewModel: TokenInstanceViewModel
    private let tokenObject: TokenObject
    private let session: WalletSession
    private let tokensDataStore: TokensDataStore
    private let analyticsCoordinator: AnalyticsCoordinator
    private let buttonsBar = ButtonsBar(configuration: .combined(buttons: 2))
    private let tokenScriptFileStatusHandler: XMLHandler
    weak var delegate: TokenInstanceViewControllerDelegate?

    private let tokenInstanceInfoPageView: TokenInstanceInfoPageView
    private var activitiesPageView: ActivitiesPageView

    private let activitiesService: ActivitiesServiceType
    private let containerView: PagesContainerView
    private let account: Wallet

    var tokenHolder: TokenHolder {
        viewModel.tokenHolder
    }

    init(session: WalletSession, tokensDataStore: TokensDataStore, assetDefinition: AssetDefinitionStore, analyticsCoordinator: AnalyticsCoordinator, token: TokenObject, viewModel: TokenInstanceViewModel, activitiesService: ActivitiesServiceType) {
        self.tokenObject = token
        self.viewModel = viewModel
        self.session = session
        self.account = session.account
        self.tokenScriptFileStatusHandler = XMLHandler(token: tokenObject, assetDefinitionStore: assetDefinition)
        self.tokensDataStore = tokensDataStore
        self.analyticsCoordinator = analyticsCoordinator
        self.activitiesService = activitiesService
        self.activitiesPageView = ActivitiesPageView(viewModel: .init(activitiesViewModel: .init()), sessions: activitiesService.sessions)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
        tokenInstanceInfoPageView = TokenInstanceInfoPageView(viewModel: .init(tokenObject: tokenObject, tokenHolder: viewModel.tokenHolder, tokenId: viewModel.tokenId))
        let pageWithFooter = PageViewWithFooter(pageView: tokenInstanceInfoPageView, footerBar: footerBar)
        containerView = PagesContainerView(pages: [pageWithFooter, activitiesPageView])

        super.init(nibName: nil, bundle: nil)

        hidesBottomBarWhenPushed = true

        activitiesPageView.delegate = self
        containerView.delegate = self

        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.anchorsConstraint(to: view)
        ])

        navigationItem.largeTitleDisplayMode = .never

        activitiesService.subscribableViewModel.subscribe { [weak self] viewModel in
            guard let strongSelf = self, let viewModel = viewModel else { return }

            strongSelf.activitiesPageView.configure(viewModel: .init(activitiesViewModel: viewModel))
        }
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hideNavigationBarTopSeparatorLine()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        showNavigationBarTopSeparatorLine()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure(viewModel: viewModel)
    }

    var isReadOnly = false {
        didSet {
            configure()
        }
    }

    func firstMatchingTokenHolder(fromTokenHolders tokenHolders: [TokenHolder]) -> TokenHolder? {
        return tokenHolders.first { $0.tokens[0].id == viewModel.tokenId }
    }

    func configure(viewModel value: TokenInstanceViewModel? = .none) {
        if let viewModel = value {
            self.viewModel = viewModel
        }

        view.backgroundColor = viewModel.backgroundColor
        title = viewModel.navigationTitle
        updateNavigationRightBarButtons(tokenScriptFileStatusHandler: tokenScriptFileStatusHandler)

        tokenInstanceInfoPageView.configure(viewModel: .init(tokenObject: tokenObject, tokenHolder: viewModel.tokenHolder, tokenId: viewModel.tokenId))

        let actions = viewModel.actions
        buttonsBar.configure(.combined(buttons: viewModel.actions.count))
        buttonsBar.viewController = self

        for (action, button) in zip(actions, buttonsBar.buttons) {
            button.setTitle(action.name, for: .normal)
            button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
            switch session.account.type {
            case .real:
                if let selection = action.activeExcludingSelection(selectedTokenHolder: viewModel.tokenHolder, tokenId: viewModel.tokenId, forWalletAddress: session.account.address, fungibleBalance: nil) {
                    if selection.denial == nil {
                        button.displayButton = false
                    }
                }
            case .watch:
                button.isEnabled = false
            }
        }
    }

    private func updateNavigationRightBarButtons(tokenScriptFileStatusHandler xmlHandler: XMLHandler) {
        let tokenScriptStatusPromise = xmlHandler.tokenScriptStatus
        if tokenScriptStatusPromise.isPending {
            let label: UIBarButtonItem = .init(title: R.string.localizable.tokenScriptVerifying(), style: .plain, target: nil, action: nil)
            tokenInstanceInfoPageView.rightBarButtonItem = label

            tokenScriptStatusPromise.done { [weak self] _ in
                self?.updateNavigationRightBarButtons(tokenScriptFileStatusHandler: xmlHandler)
            }.cauterize()
        }

        if let server = xmlHandler.server, let status = tokenScriptStatusPromise.value, server.matches(server: session.server) {
            switch status {
            case .type0NoTokenScript:
                tokenInstanceInfoPageView.rightBarButtonItem = nil
            case .type1GoodTokenScriptSignatureGoodOrOptional, .type2BadTokenScript:
                let button = createTokenScriptFileStatusButton(withStatus: status, urlOpener: self)
                tokenInstanceInfoPageView.rightBarButtonItem = UIBarButtonItem(customView: button)
            }
        } else {
            tokenInstanceInfoPageView.rightBarButtonItem = nil
        }
    }

    @objc private func actionButtonTapped(sender: UIButton) {
        let actions = viewModel.actions
        for (action, button) in zip(actions, buttonsBar.buttons) where button == sender {
            handle(action: action)
            break
        }
    }

    private func handle(action: TokenInstanceAction) {
        let tokenHolder = viewModel.tokenHolder

        switch action.type {
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
            break
        case .nftRedeem:
            redeem()
        case .nftSell:
            sell()
        case .nonFungibleTransfer:
            transfer()
        case .tokenScript:
            if let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: account.address) {
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
    }

    func redeem() {
        delegate?.didPressRedeem(token: viewModel.token, tokenHolder: viewModel.tokenHolder, in: self)
    }

    func sell() {
        let tokenHolder = viewModel.tokenHolder
        let transactionType = TransactionType.erc875Token(viewModel.token, tokenHolders: [tokenHolder])
        delegate?.didPressSell(tokenHolder: tokenHolder, for: .send(type: .transaction(transactionType)), in: self)
    }

    func transfer() {
        let tokenHolder = viewModel.tokenHolder
        let transactionType = TransactionType(token: viewModel.token, tokenHolders: [tokenHolder])
        delegate?.didPressTransfer(token: viewModel.token, tokenHolder: tokenHolder, forPaymentFlow: .send(type: .transaction(transactionType)), in: self)
    }
}

extension TokenInstanceViewController: PagesContainerViewDelegate {
    func containerView(_ containerView: PagesContainerView, didSelectPage index: Int) {
        navigationItem.rightBarButtonItem = containerView.pages[index].rightBarButtonItem
    }
}

extension TokenInstanceViewController: TokensCardCollectionInfoPageViewDelegate {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, in view: TokensCardCollectionInfoPageView) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: session.server, in: self)
    }
}

extension TokenInstanceViewController: ActivitiesPageViewDelegate {
    func didTap(activity: Activity, in view: ActivitiesPageView) {
        delegate?.didTap(activity: activity, in: self)
    }

    func didTap(transaction: TransactionInstance, in view: ActivitiesPageView) {
        delegate?.didTap(transaction: transaction, in: self)
    }
}

extension TokenInstanceViewController: VerifiableStatusViewController {
    func showInfo() {
        delegate?.didPressViewRedemptionInfo(in: self)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: tokenObject.contractAddress, server: session.server, in: self)
    }

    func open(url: URL) {
        delegate?.didPressViewContractWebPage(url, in: self)
    }
}
