// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import Combine
import AlphaWalletFoundation

struct NoTokenError: LocalizedError {
    var errorDescription: String? {
        return R.string.localizable.aWalletNoTokens()
    }
}

protocol SingleChainTokenCoordinatorDelegate: CanOpenURL, SendTransactionDelegate {
    func didTapSwap(swapTokenFlow: SwapTokenFlow, in coordinator: SingleChainTokenCoordinator)
    func didTapBridge(token: Token, service: TokenActionProvider, in coordinator: SingleChainTokenCoordinator)
    func didTapBuy(token: Token, service: TokenActionProvider, in coordinator: SingleChainTokenCoordinator)
    func didPress(for type: PaymentFlow, viewController: UIViewController, in coordinator: SingleChainTokenCoordinator)
    func didTap(transaction: Transaction, viewController: UIViewController, in coordinator: SingleChainTokenCoordinator)
    func didTap(activity: Activity, viewController: UIViewController, in coordinator: SingleChainTokenCoordinator)
    func didPostTokenScriptTransaction(_ transaction: SentTransaction, in coordinator: SingleChainTokenCoordinator)
    func didTapAddAlert(for token: Token, in coordinator: SingleChainTokenCoordinator)
    func didTapEditAlert(for token: Token, alert: PriceAlert, in coordinator: SingleChainTokenCoordinator)
}

class SingleChainTokenCoordinator: Coordinator {
    private let keystore: Keystore
    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger
    private let nftProvider: NFTProvider
    private let tokenActionsProvider: SupportedTokenActionsProvider
    private let coinTickersProvider: CoinTickersProvider
    private let activitiesService: ActivitiesServiceType
    private let sessionsProvider: SessionsProvider
    private let alertService: PriceAlertServiceType
    private let tokensPipeline: TokensProcessingPipeline
    private let currencyService: CurrencyService
    private let tokenImageFetcher: TokenImageFetcher
    private let tokensService: TokensService
    let session: WalletSession
    weak var delegate: SingleChainTokenCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    var server: RPCServer {
        session.server
    }

    init(session: WalletSession,
         keystore: Keystore,
         assetDefinitionStore: AssetDefinitionStore,
         analytics: AnalyticsLogger,
         nftProvider: NFTProvider,
         tokenActionsProvider: SupportedTokenActionsProvider,
         coinTickersProvider: CoinTickersProvider,
         activitiesService: ActivitiesServiceType,
         alertService: PriceAlertServiceType,
         tokensPipeline: TokensProcessingPipeline,
         sessionsProvider: SessionsProvider,
         currencyService: CurrencyService,
         tokenImageFetcher: TokenImageFetcher,
         tokensService: TokensService) {

        self.tokensService = tokensService
        self.tokenImageFetcher = tokenImageFetcher
        self.currencyService = currencyService
        self.sessionsProvider = sessionsProvider
        self.tokensPipeline = tokensPipeline
        self.session = session
        self.keystore = keystore
        self.assetDefinitionStore = assetDefinitionStore
        self.analytics = analytics
        self.nftProvider = nftProvider
        self.tokenActionsProvider = tokenActionsProvider
        self.coinTickersProvider = coinTickersProvider
        self.activitiesService = activitiesService
        self.alertService = alertService
    }

    func isServer(_ server: RPCServer) -> Bool {
        return session.server == server
    }

    func show(nonFungibleToken token: Token, navigationController: UINavigationController) {
        guard !token.nonZeroBalance.isEmpty else {
            navigationController.displayError(error: NoTokenError())
            return
        }

        let activitiesFilterStrategy = token.activitiesFilterStrategy
        Task { @MainActor in
            let activitiesService = await self.activitiesService.copy(activitiesFilterStrategy: activitiesFilterStrategy, transactionsFilterStrategy: TransactionDataStore.functional.transactionsFilter(for: activitiesFilterStrategy, token: token))
            let coordinator = NFTCollectionCoordinator(session: session, navigationController: navigationController, keystore: keystore, token: token, assetDefinitionStore: assetDefinitionStore, analytics: analytics, nftProvider: nftProvider, activitiesService: activitiesService, tokensService: tokensPipeline, sessionsProvider: sessionsProvider, currencyService: currencyService, tokenImageFetcher: tokenImageFetcher, tokenActionsProvider: tokenActionsProvider)
            addCoordinator(coordinator)
            coordinator.delegate = self
            coordinator.start()
        }
    }

    func show(fungibleToken token: Token, navigationController: UINavigationController) {
        //NOTE: create half mutable copy of `activitiesService` to configure it for fetching activities for specific token
        let activitiesFilterStrategy = token.activitiesFilterStrategy
        Task {
            let activitiesService = await self.activitiesService.copy(activitiesFilterStrategy: activitiesFilterStrategy, transactionsFilterStrategy: TransactionDataStore.functional.transactionsFilter(for: activitiesFilterStrategy, token: token))

            Task { @MainActor in
                let coordinator = await FungibleTokenCoordinator(token: token, navigationController: navigationController, session: session, keystore: keystore, assetDefinitionStore: assetDefinitionStore, analytics: analytics, tokenActionsProvider: tokenActionsProvider, coinTickersProvider: coinTickersProvider, activitiesService: activitiesService, alertService: alertService, tokensPipeline: tokensPipeline, sessionsProvider: sessionsProvider, currencyService: currencyService, tokenImageFetcher: tokenImageFetcher, tokensService: tokensService)
                addCoordinator(coordinator)
                coordinator.delegate = self
                coordinator.start()
            }
        }
    }

    private func showTokenInstanceActionView(forAction action: TokenInstanceAction, fungibleTokenObject token: Token, navigationController: UINavigationController) {
        let tokenHolder = session.tokenAdaptor.getTokenHolder(token: token)
        delegate?.didPress(for: .send(type: .tokenScript(action: action, token: token, tokenHolder: tokenHolder)), viewController: navigationController, in: self)
    }
}

extension SingleChainTokenCoordinator: FungibleTokenCoordinatorDelegate {
    func didTapSwap(swapTokenFlow: SwapTokenFlow, in coordinator: FungibleTokenCoordinator) {
        delegate?.didTapSwap(swapTokenFlow: swapTokenFlow, in: self)
    }

    func didTapBridge(token: Token, service: TokenActionProvider, in coordinator: FungibleTokenCoordinator) {
        delegate?.didTapBridge(token: token, service: service, in: self)
    }

    func didTapBuy(token: Token, service: TokenActionProvider, in coordinator: FungibleTokenCoordinator) {
        delegate?.didTapBuy(token: token, service: service, in: self)
    }

    func didPress(for type: PaymentFlow, viewController: UIViewController, in coordinator: FungibleTokenCoordinator) {
        delegate?.didPress(for: type, viewController: viewController, in: self)
    }

    func didTap(transaction: Transaction, viewController: UIViewController, in coordinator: FungibleTokenCoordinator) {
        delegate?.didTap(transaction: transaction, viewController: viewController, in: self)
    }

    func didTap(activity: Activity, viewController: UIViewController, in coordinator: FungibleTokenCoordinator) {
        delegate?.didTap(activity: activity, viewController: viewController, in: self)
    }

    func didClose(in coordinator: FungibleTokenCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension SingleChainTokenCoordinator: NFTCollectionCoordinatorDelegate {
    func didTap(transaction: Transaction, in coordinator: NFTCollectionCoordinator) {
        delegate?.didTap(transaction: transaction, viewController: coordinator.rootViewController, in: self)
    }

    func didTap(activity: Activity, in coordinator: NFTCollectionCoordinator) {
        delegate?.didTap(activity: activity, viewController: coordinator.rootViewController, in: self)
    }

    func didPress(for type: PaymentFlow, inViewController viewController: UIViewController, in coordinator: NFTCollectionCoordinator) {
        delegate?.didPress(for: type, viewController: viewController, in: self)
    }

    func didClose(in coordinator: NFTCollectionCoordinator) {
        removeCoordinator(coordinator)
    }

    func didPostTokenScriptTransaction(_ transaction: SentTransaction, in coordinator: NFTCollectionCoordinator) {
        delegate?.didPostTokenScriptTransaction(transaction, in: self)
    }
}

extension SingleChainTokenCoordinator: CanOpenURL {
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
