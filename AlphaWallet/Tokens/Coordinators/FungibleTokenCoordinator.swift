//
//  FungibleTokenCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 19.11.2022.
//

import Foundation
import AlphaWalletFoundation
import Combine

protocol FungibleTokenCoordinatorDelegate: AnyObject, CanOpenURL {
    func didTapSwap(swapTokenFlow: SwapTokenFlow, in coordinator: FungibleTokenCoordinator)
    func didTapBridge(token: Token, service: TokenActionProvider, in coordinator: FungibleTokenCoordinator)
    func didTapBuy(token: Token, service: TokenActionProvider, in coordinator: FungibleTokenCoordinator)
    func didPress(for type: PaymentFlow, viewController: UIViewController, in coordinator: FungibleTokenCoordinator)
    func didTap(transaction: Transaction, viewController: UIViewController, in coordinator: FungibleTokenCoordinator)
    func didTap(activity: Activity, viewController: UIViewController, in coordinator: FungibleTokenCoordinator)

    func didClose(in coordinator: FungibleTokenCoordinator)
}

class FungibleTokenCoordinator: Coordinator {
    private let keystore: Keystore
    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger
    private let tokenActionsProvider: SupportedTokenActionsProvider
    private let coinTickersProvider: CoinTickersProvider
    private let activitiesService: ActivitiesServiceType
    private let sessionsProvider: SessionsProvider
    private let session: WalletSession
    private let alertService: PriceAlertServiceType
    private let tokensPipeline: TokensProcessingPipeline
    private let token: Token
    private let navigationController: UINavigationController
    private var cancelable = Set<AnyCancellable>()
    private let currencyService: CurrencyService
    private let tokenImageFetcher: TokenImageFetcher
    private let tokensService: TokensService
    //Optional due to order of initialization It's expected to be always initialized
    private var rootViewController: FungibleTokenTabViewController?
    var coordinators: [Coordinator] = []
    weak var delegate: FungibleTokenCoordinatorDelegate?

    init(token: Token, navigationController: UINavigationController, session: WalletSession, keystore: Keystore, assetDefinitionStore: AssetDefinitionStore, analytics: AnalyticsLogger, tokenActionsProvider: SupportedTokenActionsProvider, coinTickersProvider: CoinTickersProvider, activitiesService: ActivitiesServiceType, alertService: PriceAlertServiceType, tokensPipeline: TokensProcessingPipeline, sessionsProvider: SessionsProvider, currencyService: CurrencyService, tokenImageFetcher: TokenImageFetcher, tokensService: TokensService) async {
        self.tokensService = tokensService
        self.tokenImageFetcher = tokenImageFetcher
        self.currencyService = currencyService
        self.token = token
        self.navigationController = navigationController
        self.sessionsProvider = sessionsProvider
        self.tokensPipeline = tokensPipeline
        self.session = session
        self.keystore = keystore
        self.assetDefinitionStore = assetDefinitionStore
        self.analytics = analytics
        self.tokenActionsProvider = tokenActionsProvider
        self.coinTickersProvider = coinTickersProvider
        self.activitiesService = activitiesService
        self.alertService = alertService
        self.rootViewController = await Self.createRootViewController(token: token, session: session, assetDefinitionStore: assetDefinitionStore, keystore: keystore, sessionsProvider: sessionsProvider, tokenImageFetcher: tokenImageFetcher, activitiesService: activitiesService, analytics: analytics, tokensPipeline: tokensPipeline, tokensService: tokensService, coinTickersProvider: coinTickersProvider, tokenActionsProvider: tokenActionsProvider, currencyService: currencyService, alertService: alertService, delegate: self, cancelable: &cancelable)
        Task { @MainActor in
            self.rootViewController?.delegate = self
        }
    }

    func start() {
        rootViewController!.hidesBottomBarWhenPushed = true
        rootViewController!.navigationItem.largeTitleDisplayMode = .never

        navigationController.pushViewController(rootViewController!, animated: true)
    }

    private static func buildViewController(tabBarItem: FungibleTokenTabViewModel.TabBarItem, analytics: AnalyticsLogger, keystore: Keystore, sessionsProvider: SessionsProvider, assetDefinitionStore: AssetDefinitionStore, tokenImageFetcher: TokenImageFetcher, activitiesService: ActivitiesServiceType, token: Token, coinTickersProvider: CoinTickersProvider, tokensPipeline: TokensProcessingPipeline, session: WalletSession, tokenActionsProvider: SupportedTokenActionsProvider, currencyService: CurrencyService, alertService: PriceAlertServiceType, delegate: FungibleTokenDetailsViewControllerDelegate & ActivitiesViewControllerDelegate & PriceAlertsViewControllerDelegate, cancelable: inout Set<AnyCancellable>) -> UIViewController {
        switch tabBarItem {
        case .details:
            return buildDetailsViewController(token: token, coinTickersProvider: coinTickersProvider, tokensService: tokensPipeline, session: session, assetDefinitionStore: assetDefinitionStore, tokenActionsProvider: tokenActionsProvider, currencyService: currencyService, tokenImageFetcher: tokenImageFetcher, delegate: delegate)
        case .activities:
            return buildActivitiesViewController(analytics: analytics, keystore: keystore, session: session, sessionsProvider: sessionsProvider, assetDefinitionStore: assetDefinitionStore, tokenImageFetcher: tokenImageFetcher, activitiesService: activitiesService, delegate: delegate, cancelable: &cancelable)
        case .alerts:
            return buildAlertsViewController(alertService: alertService, token: token, delegate: delegate)
        }
    }

    private static func buildActivitiesViewController(analytics: AnalyticsLogger, keystore: Keystore, session: WalletSession, sessionsProvider: SessionsProvider, assetDefinitionStore: AssetDefinitionStore, tokenImageFetcher: TokenImageFetcher, activitiesService: ActivitiesServiceType, delegate: ActivitiesViewControllerDelegate, cancelable: inout Set<AnyCancellable>) -> UIViewController {
        let viewController = ActivitiesViewController(
            analytics: analytics,
            keystore: keystore,
            wallet: session.account,
            viewModel: .init(collection: .init(activities: [])),
            sessionsProvider: sessionsProvider,
            assetDefinitionStore: assetDefinitionStore,
            tokenImageFetcher: tokenImageFetcher)

        viewController.delegate = delegate

        //FIXME: replace later with moving it to `ActivitiesViewController`
        activitiesService.activitiesPublisher
            .map { ActivityPageViewModel(activitiesViewModel: .init(collection: .init(activities: $0))) }
            .receive(on: RunLoop.main)
            .sink { [viewController] in
                viewController.configure(viewModel: $0.activitiesViewModel)
            }.store(in: &cancelable)

        Task {
            await activitiesService.start()
        }

        return viewController
    }

    private static func buildAlertsViewController(alertService: PriceAlertServiceType, token: Token, delegate: PriceAlertsViewControllerDelegate) -> UIViewController {
        let viewModel = PriceAlertsViewModel(alertService: alertService, token: token)
        let viewController = PriceAlertsViewController(viewModel: viewModel)
        viewController.delegate = delegate

        return viewController
    }

    private static func buildDetailsViewController(token: Token, coinTickersProvider: CoinTickersProvider, tokensService: TokensProcessingPipeline, session: WalletSession, assetDefinitionStore: AssetDefinitionStore, tokenActionsProvider: SupportedTokenActionsProvider, currencyService: CurrencyService, tokenImageFetcher: TokenImageFetcher, delegate: FungibleTokenDetailsViewControllerDelegate) -> UIViewController {
        lazy var viewModel = FungibleTokenDetailsViewModel(
            token: token,
            coinTickersProvider: coinTickersProvider,
            tokensService: tokensService,
            session: session,
            assetDefinitionStore: assetDefinitionStore,
            tokenActionsProvider: tokenActionsProvider,
            currencyService: currencyService,
            tokenImageFetcher: tokenImageFetcher)

        let viewController = FungibleTokenDetailsViewController(viewModel: viewModel)
        viewController.delegate = delegate

        return viewController
    }

    @MainActor private static func createRootViewController(token: Token, session: WalletSession, assetDefinitionStore: AssetDefinitionStore, keystore: Keystore, sessionsProvider: SessionsProvider, tokenImageFetcher: TokenImageFetcher, activitiesService: ActivitiesServiceType, analytics: AnalyticsLogger, tokensPipeline: TokensProcessingPipeline, tokensService: TokensService, coinTickersProvider: CoinTickersProvider, tokenActionsProvider: SupportedTokenActionsProvider, currencyService: CurrencyService, alertService: PriceAlertServiceType, delegate: FungibleTokenTabViewControllerDelegate & FungibleTokenDetailsViewControllerDelegate & ActivitiesViewControllerDelegate & PriceAlertsViewControllerDelegate, cancelable: inout Set<AnyCancellable>) async -> FungibleTokenTabViewController {
        let viewModel = await FungibleTokenTabViewModel(token: token, session: session, tokensPipeline: tokensPipeline, assetDefinitionStore: assetDefinitionStore, tokensService: tokensService)
        let viewController = FungibleTokenTabViewController(viewModel: viewModel)
        let viewControlers = viewModel.tabBarItems.map {
            buildViewController(tabBarItem: $0, analytics: analytics, keystore: keystore, sessionsProvider: sessionsProvider, assetDefinitionStore: assetDefinitionStore, tokenImageFetcher: tokenImageFetcher, activitiesService: activitiesService, token: token, coinTickersProvider: coinTickersProvider, tokensPipeline: tokensPipeline, session: session, tokenActionsProvider: tokenActionsProvider, currencyService: currencyService, alertService: alertService, delegate: delegate, cancelable: &cancelable)
        }
        viewController.set(viewControllers: viewControlers)
        viewController.delegate = delegate

        return viewController
    }
}

extension FungibleTokenCoordinator: FungibleTokenDetailsViewControllerDelegate {
    func didTapSwap(swapTokenFlow: SwapTokenFlow, in viewController: FungibleTokenDetailsViewController) {
        delegate?.didTapSwap(swapTokenFlow: swapTokenFlow, in: self)
    }

    func didTapBridge(for token: Token, service: TokenActionProvider, in viewController: FungibleTokenDetailsViewController) {
        delegate?.didTapBridge(token: token, service: service, in: self)
    }

    func didTapBuy(for token: Token, service: TokenActionProvider, in viewController: FungibleTokenDetailsViewController) {
        delegate?.didTapBuy(token: token, service: service, in: self)
    }

    func didTapSend(for token: Token, in viewController: FungibleTokenDetailsViewController) {
        delegate?.didPress(for: .send(type: .transaction(.init(fungibleToken: token))), viewController: viewController, in: self)
    }

    func didTapReceive(for token: Token, in viewController: FungibleTokenDetailsViewController) {
        delegate?.didPress(for: .request, viewController: viewController, in: self)
    }

    func didTap(action: TokenInstanceAction, token: Token, in viewController: FungibleTokenDetailsViewController) {
        guard let navigationController = viewController.navigationController else { return }

        let tokenHolder = session.tokenAdaptor.getTokenHolder(token: token)
        delegate?.didPress(for: .send(type: .tokenScript(action: action, token: token, tokenHolder: tokenHolder)), viewController: navigationController, in: self)
    }

    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }

}

extension FungibleTokenCoordinator: PriceAlertsViewControllerDelegate {
    func editAlertSelected(in viewController: PriceAlertsViewController, alert: PriceAlert) {
        let coordinator = EditPriceAlertCoordinator(
            navigationController: navigationController,
            configuration: .edit(alert),
            token: token,
            session: session,
            tokensService: tokensPipeline,
            alertService: alertService,
            currencyService: currencyService,
            tokenImageFetcher: tokenImageFetcher)

        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start()
    }

    func addAlertSelected(in viewController: PriceAlertsViewController) {
        let coordinator = EditPriceAlertCoordinator(
            navigationController: navigationController,
            configuration: .create,
            token: token,
            session: session,
            tokensService: tokensPipeline,
            alertService: alertService,
            currencyService: currencyService,
            tokenImageFetcher: tokenImageFetcher)

        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start()
    }
}

extension FungibleTokenCoordinator: ActivitiesViewControllerDelegate {
    func didPressActivity(activity: AlphaWalletFoundation.Activity, in viewController: ActivitiesViewController) {
        delegate?.didTap(activity: activity, viewController: viewController, in: self)
    }

    func didPressTransaction(transaction: AlphaWalletFoundation.Transaction, in viewController: ActivitiesViewController) {
        delegate?.didTap(transaction: transaction, viewController: viewController, in: self)
    }
}

extension FungibleTokenCoordinator: EditPriceAlertCoordinatorDelegate {
    func didClose(in coordinator: EditPriceAlertCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension FungibleTokenCoordinator: FungibleTokenTabViewControllerDelegate {
    func didClose(in viewController: FungibleTokenTabViewController) {
        delegate?.didClose(in: self)
    }

    func open(url: URL) {
        delegate?.didPressOpenWebPage(url, in: rootViewController!)
    }
}
