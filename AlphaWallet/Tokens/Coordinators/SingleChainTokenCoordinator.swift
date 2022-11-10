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
    func didTapBridge(transactionType: TransactionType, service: TokenActionProvider, in coordinator: SingleChainTokenCoordinator)
    func didTapBuy(transactionType: TransactionType, service: TokenActionProvider, in coordinator: SingleChainTokenCoordinator)
    func didPress(for type: PaymentFlow, viewController: UIViewController, in coordinator: SingleChainTokenCoordinator)
    func didTap(transaction: TransactionInstance, viewController: UIViewController, in coordinator: SingleChainTokenCoordinator)
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
    private let coinTickersFetcher: CoinTickersFetcher
    private let activitiesService: ActivitiesServiceType
    private let sessions: ServerDictionary<WalletSession>
    let session: WalletSession
    weak var delegate: SingleChainTokenCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    var server: RPCServer {
        session.server
    }
    private let alertService: PriceAlertServiceType
    private let tokensService: TokenBalanceRefreshable & TokenViewModelState & TokenHolderState
    
    init(
            session: WalletSession,
            keystore: Keystore,
            assetDefinitionStore: AssetDefinitionStore,
            analytics: AnalyticsLogger,
            nftProvider: NFTProvider,
            tokenActionsProvider: SupportedTokenActionsProvider,
            coinTickersFetcher: CoinTickersFetcher,
            activitiesService: ActivitiesServiceType,
            alertService: PriceAlertServiceType,
            tokensService: TokenBalanceRefreshable & TokenViewModelState & TokenHolderState,
            sessions: ServerDictionary<WalletSession>
    ) {
        self.sessions = sessions
        self.tokensService = tokensService
        self.session = session
        self.keystore = keystore
        self.assetDefinitionStore = assetDefinitionStore
        self.analytics = analytics
        self.nftProvider = nftProvider
        self.tokenActionsProvider = tokenActionsProvider
        self.coinTickersFetcher = coinTickersFetcher
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
        let activitiesService = self.activitiesService.copy(activitiesFilterStrategy: activitiesFilterStrategy, transactionsFilterStrategy: TransactionDataStore.functional.transactionsFilter(for: activitiesFilterStrategy, token: token))

        let coordinator = NFTCollectionCoordinator(
                session: session,
                navigationController: navigationController,
                keystore: keystore,
                token: token,
                assetDefinitionStore: assetDefinitionStore,
                analytics: analytics,
                nftProvider: nftProvider,
                activitiesService: activitiesService,
                tokensService: tokensService,
                sessions: sessions)

        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start()
    }

    func show(fungibleToken token: Token, navigationController: UINavigationController) {
        //NOTE: create half mutable copy of `activitiesService` to configure it for fetching activities for specific token
        let activitiesFilterStrategy = token.activitiesFilterStrategy
        let activitiesService = self.activitiesService.copy(activitiesFilterStrategy: activitiesFilterStrategy, transactionsFilterStrategy: TransactionDataStore.functional.transactionsFilter(for: activitiesFilterStrategy, token: token))
        let viewModel = FungibleTokenViewModel(activitiesService: activitiesService, alertService: alertService, token: token, session: session, assetDefinitionStore: assetDefinitionStore, tokenActionsProvider: tokenActionsProvider, coinTickersFetcher: coinTickersFetcher, tokensService: tokensService)
        let viewController = FungibleTokenViewController(keystore: keystore, analytics: analytics, viewModel: viewModel, activitiesService: activitiesService, sessions: sessions)
        viewController.delegate = self

        navigationController.pushViewController(viewController, animated: true)
    }

    private func showTokenInstanceActionView(forAction action: TokenInstanceAction, fungibleTokenObject token: Token, navigationController: UINavigationController) {
        let tokenHolder = token.getTokenHolder(assetDefinitionStore: assetDefinitionStore, forWallet: session.account)
        delegate?.didPress(for: .send(type: .tokenScript(action: action, token: token, tokenHolder: tokenHolder)), viewController: navigationController, in: self)
    }

    func didClose(in viewController: FungibleTokenViewController) {
        //no-op
    } 
}

extension SingleChainTokenCoordinator: NFTCollectionCoordinatorDelegate {
    func didTap(transaction: TransactionInstance, in coordinator: NFTCollectionCoordinator) {
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

extension SingleChainTokenCoordinator: FungibleTokenViewControllerDelegate {

    func didTapAddAlert(for token: Token, in viewController: FungibleTokenViewController) {
        delegate?.didTapAddAlert(for: token, in: self)
    }

    func didTapEditAlert(for token: Token, alert: PriceAlert, in viewController: FungibleTokenViewController) {
        delegate?.didTapEditAlert(for: token, alert: alert, in: self)
    }

    func didTapSwap(swapTokenFlow: SwapTokenFlow, in viewController: FungibleTokenViewController) {
        delegate?.didTapSwap(swapTokenFlow: swapTokenFlow, in: self)
    }

    func didTapBridge(for token: Token, service: TokenActionProvider, in viewController: FungibleTokenViewController) {
        delegate?.didTapBridge(transactionType: .init(fungibleToken: token), service: service, in: self)
    }

    func didTapBuy(for token: Token, service: TokenActionProvider, in viewController: FungibleTokenViewController) {
        delegate?.didTapBuy(transactionType: .init(fungibleToken: token), service: service, in: self)
    }

    func didTapSend(for token: Token, in viewController: FungibleTokenViewController) {
        delegate?.didPress(for: .send(type: .transaction(.init(fungibleToken: token))), viewController: viewController, in: self)
    }

    func didTapReceive(for token: Token, in viewController: FungibleTokenViewController) {
        delegate?.didPress(for: .request, viewController: viewController, in: self)
    }

    func didTap(activity: Activity, in viewController: FungibleTokenViewController) {
        delegate?.didTap(activity: activity, viewController: viewController, in: self)
    }

    func didTap(transaction: TransactionInstance, in viewController: FungibleTokenViewController) {
        delegate?.didTap(transaction: transaction, viewController: viewController, in: self)
    }

    func didTap(action: TokenInstanceAction, token: Token, in viewController: FungibleTokenViewController) {
        guard let navigationController = viewController.navigationController else { return }

        showTokenInstanceActionView(forAction: action, fungibleTokenObject: token, navigationController: navigationController)
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
