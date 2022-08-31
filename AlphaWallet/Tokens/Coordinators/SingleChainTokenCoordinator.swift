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
    private let openSea: OpenSea
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
            openSea: OpenSea,
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
        self.openSea = openSea
        self.tokenActionsProvider = tokenActionsProvider
        self.coinTickersFetcher = coinTickersFetcher
        self.activitiesService = activitiesService
        self.alertService = alertService
    }

    func isServer(_ server: RPCServer) -> Bool {
        return session.server == server
    }

    func showTokenList(for type: PaymentFlow, token: Token, navigationController: UINavigationController) {
        guard !token.nonZeroBalance.isEmpty else {
            navigationController.displayError(error: NoTokenError())
            return
        }

        guard let transactionType = type.transactionType else { return }

        let activitiesFilterStrategy = transactionType.activitiesFilterStrategy
        let activitiesService = self.activitiesService.copy(activitiesFilterStrategy: activitiesFilterStrategy, transactionsFilterStrategy: TransactionDataStore.functional.transactionsFilter(for: activitiesFilterStrategy, token: transactionType.tokenObject))

        let coordinator = NFTCollectionCoordinator(
                session: session,
                navigationController: navigationController,
                keystore: keystore,
                token: token,
                assetDefinitionStore: assetDefinitionStore,
                analytics: analytics,
                openSea: openSea,
                activitiesService: activitiesService,
                tokensService: tokensService,
                sessions: sessions)

        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start()
    }

    func show(fungibleToken token: Token, transactionType: TransactionType, navigationController: UINavigationController) {
        //NOTE: create half mutable copy of `activitiesService` to configure it for fetching activities for specific token
        let activitiesFilterStrategy = transactionType.activitiesFilterStrategy
        let activitiesService = self.activitiesService.copy(activitiesFilterStrategy: activitiesFilterStrategy, transactionsFilterStrategy: TransactionDataStore.functional.transactionsFilter(for: activitiesFilterStrategy, token: transactionType.tokenObject))
        let viewModel = FungibleTokenViewModel(activitiesService: activitiesService, alertService: alertService, transactionType: transactionType, session: session, assetDefinitionStore: assetDefinitionStore, tokenActionsProvider: tokenActionsProvider, coinTickersFetcher: coinTickersFetcher, tokensService: tokensService)
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

    func didTapBridge(transactionType: TransactionType, service: TokenActionProvider, in viewController: FungibleTokenViewController) {
        delegate?.didTapBridge(transactionType: transactionType, service: service, in: self)
    }

    func didTapBuy(transactionType: TransactionType, service: TokenActionProvider, in viewController: FungibleTokenViewController) {
        delegate?.didTapBuy(transactionType: transactionType, service: service, in: self)
    }

    func didTapSend(forTransactionType transactionType: TransactionType, in viewController: FungibleTokenViewController) {
        delegate?.didPress(for: .send(type: .transaction(transactionType)), viewController: viewController, in: self)
    }

    func didTapReceive(forTransactionType transactionType: TransactionType, in viewController: FungibleTokenViewController) {
        delegate?.didPress(for: .request, viewController: viewController, in: self)
    }

    func didTap(activity: Activity, in viewController: FungibleTokenViewController) {
        delegate?.didTap(activity: activity, viewController: viewController, in: self)
    }

    func didTap(transaction: TransactionInstance, in viewController: FungibleTokenViewController) {
        delegate?.didTap(transaction: transaction, viewController: viewController, in: self)
    }

    func didTap(action: TokenInstanceAction, transactionType: TransactionType, in viewController: FungibleTokenViewController) {
        guard let navigationController = viewController.navigationController else { return }

        let token: Token
        switch transactionType {
        case .erc20Token(let erc20Token, _, _):
            token = erc20Token
        case .dapp, .erc721Token, .erc875Token, .erc875TokenOrder, .erc721ForTicketToken, .erc1155Token, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            return
        case .nativeCryptocurrency:
            token = MultipleChainsTokensDataStore.functional.etherToken(forServer: server)
            showTokenInstanceActionView(forAction: action, fungibleTokenObject: token, navigationController: navigationController)
            return
        }
        switch action.type {
        case .tokenScript:
            showTokenInstanceActionView(forAction: action, fungibleTokenObject: token, navigationController: navigationController)
        case .erc20Send, .erc20Receive, .nftRedeem, .nftSell, .nonFungibleTransfer, .swap, .buy, .bridge:
            //Couldn't have reached here
            break
        }
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
