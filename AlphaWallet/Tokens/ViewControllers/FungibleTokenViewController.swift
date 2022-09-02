// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Combine
import AlphaWalletFoundation

protocol FungibleTokenViewControllerDelegate: class, CanOpenURL {
    func didTapSwap(swapTokenFlow: SwapTokenFlow, in viewController: FungibleTokenViewController)
    func didTapBridge(transactionType: TransactionType, service: TokenActionProvider, in viewController: FungibleTokenViewController)
    func didTapBuy(transactionType: TransactionType, service: TokenActionProvider, in viewController: FungibleTokenViewController)
    func didTapSend(forTransactionType transactionType: TransactionType, in viewController: FungibleTokenViewController)
    func didTapReceive(forTransactionType transactionType: TransactionType, in viewController: FungibleTokenViewController)
    func didTap(transaction: TransactionInstance, in viewController: FungibleTokenViewController)
    func didTap(activity: Activity, in viewController: FungibleTokenViewController)
    func didTap(action: TokenInstanceAction, transactionType: TransactionType, in viewController: FungibleTokenViewController)
    func didTapAddAlert(for token: Token, in viewController: FungibleTokenViewController)
    func didTapEditAlert(for token: Token, alert: PriceAlert, in viewController: FungibleTokenViewController)
    func didClose(in viewController: FungibleTokenViewController)
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
        return ActivitiesPageView(analytics: analytics, keystore: keystore, wallet: viewModel.wallet, viewModel: .init(activitiesViewModel: .init(collection: .init())), sessions: sessions, assetDefinitionStore: viewModel.assetDefinitionStore)
    }()
    private lazy var alertsPageView: PriceAlertsPageView = {
        return PriceAlertsPageView(viewModel: .init(alerts: []))
    }()
    private let activitiesService: ActivitiesServiceType
    private let analytics: AnalyticsLogger
    private let keystore: Keystore
    private var cancelable = Set<AnyCancellable>()
    private let appear = PassthroughSubject<Void, Never>()
    private let sessions: ServerDictionary<WalletSession>
    weak var delegate: FungibleTokenViewControllerDelegate?

    init(keystore: Keystore, analytics: AnalyticsLogger, viewModel: FungibleTokenViewModel, activitiesService: ActivitiesServiceType, sessions: ServerDictionary<WalletSession>) {
        self.sessions = sessions
        self.viewModel = viewModel
        self.keystore = keystore
        self.activitiesService = activitiesService
        self.analytics = analytics

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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hideNavigationBarTopSeparatorLine()

        appear.send(())
        tokenInfoPageView.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        showNavigationBarTopSeparatorLine()
    }

    private func bind(viewModel: FungibleTokenViewModel) {
        view.backgroundColor = viewModel.backgroundColor

        updateNavigationRightBarButtons(tokenScriptFileStatusHandler: viewModel.tokenScriptFileStatusHandler)

        let input = FungibleTokenViewModelInput(appear: appear.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)
        output.viewState.sink { [weak self] state in
            self?.title = state.navigationTitle
            self?.configureActionButtons(with: state.actions)
        }.store(in: &cancelable)

        output.activities.sink { [weak activitiesPageView] viewModel in
            activitiesPageView?.configure(viewModel: viewModel)
        }.store(in: &cancelable)

        output.alerts.sink { [weak alertsPageView] viewModel in
            alertsPageView?.configure(viewModel: viewModel)
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

    private func updateNavigationRightBarButtons(tokenScriptFileStatusHandler xmlHandler: XMLHandler) {
        if Features.default.isAvailable(.isTokenScriptSignatureStatusEnabled) {
            let tokenScriptStatusPromise = xmlHandler.tokenScriptStatus
            if tokenScriptStatusPromise.isPending {
                let label: UIBarButtonItem = .init(title: R.string.localizable.tokenScriptVerifying(), style: .plain, target: nil, action: nil)
                navigationItem.rightBarButtonItem = label

                tokenScriptStatusPromise.done { [weak self] _ in
                    self?.updateNavigationRightBarButtons(tokenScriptFileStatusHandler: xmlHandler)
                }.cauterize()
            }

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
            case .swap:
                delegate?.didTapSwap(swapTokenFlow: .swapToken(token: viewModel.transactionType.tokenObject), in: self)
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
                delegate?.didTapBridge(transactionType: viewModel.transactionType, service: service, in: self)
            case .buy(let service):
                delegate?.didTapBuy(transactionType: viewModel.transactionType, service: service, in: self)
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
        viewModel.removeAlert(at: indexPath)
    }

    func updateAlert(in view: PriceAlertsPageView, value: Bool, indexPath: IndexPath) {
        viewModel.updateAlert(value: value, at: indexPath)
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

extension FungibleTokenViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
    }
}
