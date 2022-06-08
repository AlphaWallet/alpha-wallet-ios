// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
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
    func didTapAddAlert(for token: Token, in viewController: FungibleTokenViewController)
    func didTapEditAlert(for token: Token, alert: PriceAlert, in viewController: FungibleTokenViewController)
}

class FungibleTokenViewController: UIViewController {
    private var viewModel: FungibleTokenViewModel
    private let buttonsBar = HorizontalButtonsBar(configuration: .combined(buttons: 2))
    private lazy var tokenInfoPageView: TokenInfoPageView = {
        let view = TokenInfoPageView(viewModel: viewModel.tokenInfoPageViewModel)
        view.delegate = self

        return view
    }()
    private lazy var activitiesPageView: ActivitiesPageView = {
        return ActivitiesPageView(analyticsCoordinator: analyticsCoordinator, keystore: keystore, wallet: viewModel.wallet, viewModel: .init(activitiesViewModel: .init()), sessions: activitiesService.sessions, assetDefinitionStore: viewModel.assetDefinitionStore)
    }()
    private lazy var alertsPageView: PriceAlertsPageView = {
        return PriceAlertsPageView(viewModel: .init(alerts: []))
    }()
    private let activitiesService: ActivitiesServiceType
    private let alertService: PriceAlertServiceType
    private let analyticsCoordinator: AnalyticsCoordinator
    private let keystore: Keystore
    private var cancelable = Set<AnyCancellable>()
    weak var delegate: FungibleTokenViewControllerDelegate?

    init(keystore: Keystore, analyticsCoordinator: AnalyticsCoordinator, viewModel: FungibleTokenViewModel, activitiesService: ActivitiesServiceType, alertService: PriceAlertServiceType) {
        self.viewModel = viewModel
        self.keystore = keystore
        self.activitiesService = activitiesService
        self.alertService = alertService
        self.analyticsCoordinator = analyticsCoordinator

        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true

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

        activitiesPageView.delegate = self
        alertsPageView.delegate = self
        buttonsBar.viewController = self

        bind(viewModel: viewModel)

        subscribeForAlerts()
        subscribeForActivities()
    } 

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hideNavigationBarTopSeparatorLine()

        viewModel.viewDidLoad()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        showNavigationBarTopSeparatorLine()
    }

    private func bind(viewModel: FungibleTokenViewModel) {
        view.backgroundColor = viewModel.backgroundColor
        title = viewModel.navigationTitle

        alertsPageView.configure(viewModel: .init(alerts: alertService.alerts(forStrategy: .token(viewModel.token))))
        updateNavigationRightBarButtons(tokenScriptFileStatusHandler: viewModel.tokenScriptFileStatusHandler)

        viewModel.actionsPublisher
            .sink { [weak self] actions in
                self?.configureActionButtons(with: actions)
            }.store(in: &cancelable)
    }

    private func configureActionButtons(with actions: [TokenInstanceAction]) {
        buttonsBar.configure(.combined(buttons: actions.count))

        for (action, button) in zip(actions, buttonsBar.buttons) {
            button.setTitle(action.name, for: .normal)
            button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)

            switch viewModel.buttonState(for: action) {
            case .isEnabled(let isEnabled):
                button.isEnabled = isEnabled
            case .isDisplayed(let isDisplayed):
                button.displayButton = isDisplayed
            case .noOption:
                continue
            }
        }
    }

    private func subscribeForActivities() {
        activitiesService.activitiesPublisher
            .receive(on: RunLoop.main)
            .sink { [weak activitiesPageView] activities in
                activitiesPageView?.configure(viewModel: .init(activitiesViewModel: .init(activities: activities)))
            }.store(in: &cancelable)
    }

    private func subscribeForAlerts() {
        alertService.alertsPublisher(forStrategy: .token(viewModel.token))
            .sink { [weak alertsPageView] alerts in
                alertsPageView?.configure(viewModel: .init(alerts: alerts))
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
            if let server = xmlHandler.server, let status = tokenScriptStatusPromise.value, server.matches(server: viewModel.session.server) {
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

    @objc private func actionButtonTapped(sender: UIButton) {
        let actions = viewModel.actions
        for (action, button) in zip(actions, buttonsBar.buttons) where button == sender {
            switch action.type {
            case .swap(let service):
                delegate?.didTapSwap(forTransactionType: viewModel.transactionType, service: service, in: self)
            case .erc20Send:
                delegate?.didTapSend(forTransactionType: viewModel.transactionType, in: self)
            case .erc20Receive:
                delegate?.didTapReceive(forTransactionType: viewModel.transactionType, in: self)
            case .nftRedeem, .nftSell, .nonFungibleTransfer:
                break
            case .tokenScript:
                if let message = viewModel.tokenScriptWarningMessage(for: action) {
                    guard case .warning(let denialMessage) = message else { return }
                    UIAlertController.alert(message: denialMessage, alertButtonTitles: [R.string.localizable.oK()], alertButtonStyles: [.default], viewController: self)
                } else {
                    delegate?.didTap(action: action, transactionType: viewModel.transactionType, in: self)
                }
            case .bridge(let service):
                delegate?.didTapBridge(forTransactionType: viewModel.transactionType, service: service, in: self)
            case .buy(let service):
                delegate?.didTapBuy(forTransactionType: viewModel.transactionType, service: service, in: self)
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
        delegate?.didPressViewContractWebPage(forContract: contract, server: viewModel.session.server, in: self)
    }
}

extension FungibleTokenViewController: PriceAlertsPageViewDelegate {
    func addAlertSelected(in view: PriceAlertsPageView) {
        delegate?.didTapAddAlert(for: viewModel.token, in: self)
    }

    func editAlertSelected(in view: PriceAlertsPageView, alert: PriceAlert) {
        delegate?.didTapEditAlert(for: viewModel.token, alert: alert, in: self)
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
