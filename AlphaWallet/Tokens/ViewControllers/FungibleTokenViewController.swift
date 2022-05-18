// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import PromiseKit
import Combine

protocol FungibleTokenViewControllerDelegate: class, CanOpenURL {
    func didTapSwap(forTransactionType transactionType: TransactionType, service: TokenActionProvider, in viewController: FungibleTokenViewController)
    func didTapBridge(forTransactionType transactionType: TransactionType, service: TokenActionProvider, in viewController: FungibleTokenViewController)
    func didTapBuy(forTransactionType transactionType: TransactionType, service: TokenActionProvider, in viewController: FungibleTokenViewController)
    func didTapSend(forTransactionType transactionType: TransactionType, in viewController: FungibleTokenViewController)
    func didTapReceive(forTransactionType transactionType: TransactionType, in viewController: FungibleTokenViewController)
    func didTap(transaction: TransactionInstance, in viewController: FungibleTokenViewController)
    func didTap(activity: Activity, in viewController: FungibleTokenViewController)
    func didTap(action: TokenInstanceAction, transactionType: TransactionType, in viewController: FungibleTokenViewController)
    func didTapAddAlert(for tokenObject: TokenObject, in viewController: FungibleTokenViewController)
    func didTapEditAlert(for tokenObject: TokenObject, alert: PriceAlert, in viewController: FungibleTokenViewController)
}

class FungibleTokenViewController: UIViewController {
    private var viewModel: FungibleTokenViewModel
    private var tokenHolder: TokenHolder?
    private let token: TokenObject
    private let session: WalletSession
    private let assetDefinitionStore: AssetDefinitionStore
    private let transactionType: TransactionType
    private let buttonsBar = HorizontalButtonsBar(configuration: .combined(buttons: 2))
    private lazy var tokenScriptFileStatusHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
    private lazy var tokenInfoPageView: TokenInfoPageView = {
        let view = TokenInfoPageView(server: session.server, token: token, config: session.config, transactionType: transactionType)
        view.delegate = self

        return view
    }()
    private var activitiesPageView: ActivitiesPageView
    private var alertsPageView: PriceAlertsPageView
    private let activitiesService: ActivitiesServiceType
    private let alertService: PriceAlertServiceType
    private let tokenActionsProvider: SupportedTokenActionsProvider
    private var cancelable = Set<AnyCancellable>()

    weak var delegate: FungibleTokenViewControllerDelegate?

    init(keystore: Keystore, session: WalletSession, assetDefinition: AssetDefinitionStore, transactionType: TransactionType, analyticsCoordinator: AnalyticsCoordinator, token: TokenObject, viewModel: FungibleTokenViewModel, activitiesService: ActivitiesServiceType, alertService: PriceAlertServiceType, tokenActionsProvider: SupportedTokenActionsProvider) {
        self.tokenActionsProvider = tokenActionsProvider
        self.token = token
        self.viewModel = viewModel
        self.session = session
        self.assetDefinitionStore = assetDefinition
        self.transactionType = transactionType
        self.activitiesService = activitiesService
        self.alertService = alertService
        self.tokenHolder = viewModel.token?.getTokenHolder(assetDefinitionStore: assetDefinitionStore, forWallet: session.account)

        activitiesPageView = ActivitiesPageView(analyticsCoordinator: analyticsCoordinator, keystore: keystore, wallet: session.account, viewModel: .init(activitiesViewModel: .init()), sessions: activitiesService.sessions, assetDefinitionStore: assetDefinition)
        alertsPageView = PriceAlertsPageView(viewModel: .init(alerts: []))

        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true

        activitiesPageView.delegate = self
        alertsPageView.delegate = self

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
        let pageWithFooter = PageViewWithFooter(pageView: tokenInfoPageView, footerBar: footerBar)
        let pages: [PageViewType]
        if Features.default.isAvailable(.isAlertsEnabled) && viewModel.hasCoinTicker {
            pages = [pageWithFooter, activitiesPageView, alertsPageView]
        } else {
            pages = [pageWithFooter, activitiesPageView]
        }

        let containerView = PagesContainerView(pages: pages)

        view.addSubview(containerView)
        NSLayoutConstraint.activate([containerView.anchorsConstraint(to: view)])

        navigationItem.largeTitleDisplayMode = .never
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure(viewModel: viewModel)

        subscribeForBalanceUpdates()
        subscribeForAlerts()
        subscribeForActivities()
        subscribeForTokenActions()
        subscribeForAssetDefinitionChanges()
        subscribeForTokenTokenHolder()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hideNavigationBarTopSeparatorLine()

        viewModel.refreshBalance()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        showNavigationBarTopSeparatorLine()
    }

    func configure(viewModel: FungibleTokenViewModel) {
        self.viewModel = viewModel

        view.backgroundColor = viewModel.backgroundColor
        title = token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
        updateNavigationRightBarButtons(tokenScriptFileStatusHandler: tokenScriptFileStatusHandler)

        var viewModel2 = tokenInfoPageView.viewModel
        viewModel2.values = viewModel.chartHistory

        tokenInfoPageView.configure(viewModel: viewModel2)
        alertsPageView.configure(viewModel: .init(alerts: alertService.alerts(forStrategy: .token(token))))

        let actions = viewModel.actions
        buttonsBar.configure(.combined(buttons: viewModel.actions.count))
        buttonsBar.viewController = self

        func _configButton(action: TokenInstanceAction, viewModel: FungibleTokenViewModel, button: BarButton) {
            if let tokenHolder = tokenHolder, let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: session.account.address, fungibleBalance: viewModel.fungibleBalance) {
                if selection.denial == nil {
                    button.displayButton = false
                }
            }
        }

        for (action, button) in zip(actions, buttonsBar.buttons) {
            button.setTitle(action.name, for: .normal)
            button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
            switch session.account.type {
            case .real:
                _configButton(action: action, viewModel: viewModel, button: button)
            case .watch:
                //TODO pass in Config instance instead
                if Config().development.shouldPretendIsRealWallet {
                    _configButton(action: action, viewModel: viewModel, button: button)
                } else {
                    button.isEnabled = false
                }
            }
        }
    }

    private func subscribeForTokenTokenHolder() {
        tokenHolder?.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let strongSelf = self else { return }

                let viewModel = FungibleTokenViewModel(transactionType: strongSelf.transactionType, session: strongSelf.session, assetDefinitionStore: strongSelf.assetDefinitionStore, tokenActionsProvider: strongSelf.viewModel.tokenActionsProvider)
                strongSelf.configure(viewModel: viewModel)
            }.store(in: &cancelable)
    }

    private func subscribeForTokenActions() {
        tokenActionsProvider.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let strongSelf = self else { return }

                let viewModel = FungibleTokenViewModel(transactionType: strongSelf.transactionType, session: strongSelf.session, assetDefinitionStore: strongSelf.assetDefinitionStore, tokenActionsProvider: strongSelf.viewModel.tokenActionsProvider)
                strongSelf.configure(viewModel: viewModel)
            }.store(in: &cancelable)
    }

    private func subscribeForActivities() {
        activitiesService.viewModelPublisher
            .receive(on: RunLoop.main)
            .sink { [weak activitiesPageView] viewModel in
                activitiesPageView?.configure(viewModel: .init(activitiesViewModel: viewModel))
            }.store(in: &cancelable)
    }

    private func subscribeForAlerts() {
        alertService.alertsPublisher(forStrategy: .token(token))
            .sink { [weak alertsPageView] alerts in
                alertsPageView?.configure(viewModel: .init(alerts: alerts))
            }.store(in: &cancelable)
    }

    private func subscribeForAssetDefinitionChanges() {
        assetDefinitionStore
            .assetBodyChanged(for: transactionType.contract)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let strongSelf = self else { return }

                let viewModel = FungibleTokenViewModel(transactionType: strongSelf.transactionType, session: strongSelf.session, assetDefinitionStore: strongSelf.assetDefinitionStore, tokenActionsProvider: strongSelf.viewModel.tokenActionsProvider)
                strongSelf.configure(viewModel: viewModel)
            }.store(in: &cancelable)
    }

    private func updateNavigationRightBarButtons(tokenScriptFileStatusHandler xmlHandler: XMLHandler) {
        let tokenScriptStatusPromise = xmlHandler.tokenScriptStatus
        if tokenScriptStatusPromise.isPending {
            let label: UIBarButtonItem = .init(title: R.string.localizable.tokenScriptVerifying(), style: .plain, target: nil, action: nil)
            navigationItem.rightBarButtonItem = label

            tokenScriptStatusPromise.done { [weak self] _ in
                self?.updateNavigationRightBarButtons(tokenScriptFileStatusHandler: xmlHandler)
            }.cauterize()
        }

        if Features.default.isAvailable(.isTokenScriptSignatureStatusEnabled) {
            if let server = xmlHandler.server, let status = tokenScriptStatusPromise.value, server.matches(server: session.server) {
                switch status {
                case .type0NoTokenScript:
                    navigationItem.rightBarButtonItem = nil
                case .type1GoodTokenScriptSignatureGoodOrOptional, .type2BadTokenScript:
                    let button = createTokenScriptFileStatusButton(withStatus: status, urlOpener: self)
                    navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
                }
            } else {
                navigationItem.rightBarButtonItem = nil
            }
        } else {
            //no-op
        }
    }

    private func subscribeForBalanceUpdates() {
        switch transactionType {
        case .nativeCryptocurrency:
            session.tokenBalanceService
                .etherBalance
                .receive(on: RunLoop.main)
                .sink { [weak self] viewModel in
                    guard let celf = self, let viewModel = viewModel else { return }

                    celf.tokenInfoPageView.viewModel.title = "\(viewModel.amountShort) \(viewModel.symbol)"
                    celf.tokenInfoPageView.viewModel.ticker = viewModel.ticker
                    celf.tokenInfoPageView.viewModel.currencyAmount = viewModel.currencyAmount

                    celf.configure(viewModel: celf.viewModel)
                }.store(in: &cancelable)
        case .erc20Token(let token, _, _):
            let amount = EtherNumberFormatter.short.string(from: token.valueBigInt, decimals: token.decimals)
            tokenInfoPageView.viewModel.title = "\(amount) \(token.symbolInPluralForm(withAssetDefinitionStore: assetDefinitionStore))"
            tokenInfoPageView.viewModel.ticker = session.tokenBalanceService.coinTicker(token.addressAndRPCServer)

            session.tokenBalanceService
                .tokenBalancePublisher(token.addressAndRPCServer)
                .receive(on: RunLoop.main)
                .sink { [weak self] viewModel in
                    guard let strongSelf = self, let viewModel = viewModel else { return }

                    strongSelf.tokenInfoPageView.viewModel.currencyAmount = viewModel.currencyAmount
                    strongSelf.configure(viewModel: strongSelf.viewModel)
                }.store(in: &cancelable)
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            break
        }
    }

    @objc private func actionButtonTapped(sender: UIButton) {
        let actions = viewModel.actions
        for (action, button) in zip(actions, buttonsBar.buttons) where button == sender {
            switch action.type {
            case .swap(let service):
                delegate?.didTapSwap(forTransactionType: transactionType, service: service, in: self)
            case .erc20Send:
                delegate?.didTapSend(forTransactionType: transactionType, in: self)
            case .erc20Receive:
                delegate?.didTapReceive(forTransactionType: transactionType, in: self)
            case .nftRedeem, .nftSell, .nonFungibleTransfer:
                break
            case .tokenScript:
                if let tokenHolder = tokenHolder, let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: session.account.address, fungibleBalance: viewModel.fungibleBalance) {
                    if let denialMessage = selection.denial {
                        UIAlertController.alert(
                                message: denialMessage,
                                alertButtonTitles: [R.string.localizable.oK()],
                                alertButtonStyles: [.default],
                                viewController: self
                        )
                    } else {
                        //no-op shouldn't have reached here since the button should be disabled. So just do nothing to be safe
                    }
                } else {
                    delegate?.didTap(action: action, transactionType: transactionType, in: self)
                }
            case .bridge(let service):
                delegate?.didTapBridge(forTransactionType: transactionType, service: service, in: self)
            case .buy(let service):
                delegate?.didTapBuy(forTransactionType: transactionType, service: service, in: self)
            }
            break
        }
    }
}

extension FungibleTokenViewController: CanOpenURL2 {
    func open(url: URL) {
        delegate?.didPressOpenWebPage(url, in: self)
    }
}

extension FungibleTokenViewController: TokenInfoPageViewDelegate {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, in tokenInfoPageView: TokenInfoPageView) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: session.server, in: self)
    }
}

extension FungibleTokenViewController: PriceAlertsPageViewDelegate {
    func addAlertSelected(in view: PriceAlertsPageView) {
        delegate?.didTapAddAlert(for: token, in: self)
    }

    func editAlertSelected(in view: PriceAlertsPageView, alert: PriceAlert) {
        delegate?.didTapEditAlert(for: token, alert: alert, in: self)
    }

    func removeAlert(in view: PriceAlertsPageView, indexPath: IndexPath) {
        alertService.remove(indexPath: indexPath)
    }

    func updateAlert(in view: PriceAlertsPageView, value: Bool, indexPath: IndexPath) {
        alertService.update(indexPath: indexPath, update: .enabled(value))
    }
}

extension FungibleTokenViewController: ActivitiesPageViewDelegate {
    func didTap(activity: Activity, in view: ActivitiesPageView) {
        delegate?.didTap(activity: activity, in: self)
    }

    func didTap(transaction: TransactionInstance, in view: ActivitiesPageView) {
        delegate?.didTap(transaction: transaction, in: self)
    }
}
