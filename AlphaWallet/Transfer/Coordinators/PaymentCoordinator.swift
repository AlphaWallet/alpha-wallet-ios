// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import Combine
import AlphaWalletFoundation

protocol PaymentCoordinatorDelegate: CanOpenURL, BuyCryptoDelegate {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: PaymentCoordinator)
    func didFinish(_ result: ConfirmResult, in coordinator: PaymentCoordinator)
    func didCancel(in coordinator: PaymentCoordinator)
    func didSelectTokenHolder(tokenHolder: TokenHolder, in coordinator: PaymentCoordinator)
}

class PaymentCoordinator: Coordinator {
    private var session: WalletSession {
        return sessionProvider.session(for: server)!
    }
    private let server: RPCServer
    private let sessionProvider: SessionsProvider
    private let keystore: Keystore
    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger
    private let tokenCollection: TokenCollection
    private let tokenSwapper: TokenSwapper
    private var shouldRestoreNavigationBarIsHiddenState: Bool
    private var latestNavigationStackViewController: UIViewController?
    private let reachabilityManager: ReachabilityManagerProtocol
    private let domainResolutionService: DomainResolutionServiceType
    private let tokensFilter: TokensFilter
    let flow: PaymentFlow
    weak var delegate: PaymentCoordinatorDelegate?
    var coordinators: [Coordinator] = []
    let navigationController: UINavigationController

    init(
            navigationController: UINavigationController,
            flow: PaymentFlow,
            server: RPCServer,
            sessionProvider: SessionsProvider,
            keystore: Keystore,
            assetDefinitionStore: AssetDefinitionStore,
            analytics: AnalyticsLogger,
            tokenCollection: TokenCollection,
            reachabilityManager: ReachabilityManagerProtocol = ReachabilityManager(),
            domainResolutionService: DomainResolutionServiceType,
            tokenSwapper: TokenSwapper,
            tokensFilter: TokensFilter
    ) {
        self.tokensFilter = tokensFilter
        self.tokenSwapper = tokenSwapper
        self.reachabilityManager = reachabilityManager
        self.tokenCollection = tokenCollection
        self.navigationController = navigationController
        self.server = server
        self.sessionProvider = sessionProvider
        self.flow = flow
        self.keystore = keystore
        self.assetDefinitionStore = assetDefinitionStore
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService

        shouldRestoreNavigationBarIsHiddenState = navigationController.navigationBar.isHidden
        latestNavigationStackViewController = navigationController.viewControllers.last
    }

    private func startWithSendCoordinator(transactionType: TransactionType) {
        let coordinator = SendCoordinator(
            transactionType: transactionType,
            navigationController: navigationController,
            session: session,
            keystore: keystore,
            tokensService: tokenCollection,
            assetDefinitionStore: assetDefinitionStore,
            analytics: analytics,
            domainResolutionService: domainResolutionService
        )
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func startWithSendCollectiblesCoordinator(token: Token, transferType: Erc1155TokenTransactionType, tokenHolders: [TokenHolder]) {
        let coordinator = TransferCollectiblesCoordinator(session: session, navigationController: navigationController, keystore: keystore, filteredTokenHolders: tokenHolders, token: token, assetDefinitionStore: assetDefinitionStore, analytics: analytics, domainResolutionService: domainResolutionService, tokensService: tokenCollection)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func startWithSendNFTCoordinator(transactionType: TransactionType, token: Token, tokenHolder: TokenHolder) {
        let coordinator = TransferNFTCoordinator(session: session, navigationController: navigationController, keystore: keystore, tokenHolder: tokenHolder, token: token, transactionType: transactionType, assetDefinitionStore: assetDefinitionStore, analytics: analytics, domainResolutionService: domainResolutionService, tokensService: tokenCollection)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func startWithTokenScriptCoordinator(action: TokenInstanceAction, token: Token, tokenHolder: TokenHolder) {
        let coordinator = TokenScriptCoordinator(session: session, navigationController: navigationController, keystore: keystore, tokenHolder: tokenHolder, tokenObject: token, assetDefinitionStore: assetDefinitionStore, analytics: analytics, domainResolutionService: domainResolutionService, action: action, tokensService: tokenCollection)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func startWithSwapCoordinator(swapPair: SwapPair) {
        let configurator = SwapOptionsConfigurator(sessionProvider: sessionProvider, swapPair: swapPair, tokenCollection: tokenCollection, reachabilityManager: reachabilityManager, tokenSwapper: tokenSwapper)
        let coordinator = SwapTokensCoordinator(navigationController: navigationController, configurator: configurator, keystore: keystore, analytics: analytics, domainResolutionService: domainResolutionService, assetDefinitionStore: assetDefinitionStore, tokenCollection: tokenCollection, tokensFilter: tokensFilter)
        coordinator.start()
        coordinator.delegate = self
        addCoordinator(coordinator)
    }

    func start() {
        if shouldRestoreNavigationBarIsHiddenState {
            self.navigationController.setNavigationBarHidden(false, animated: false)
        }

        func _startPaymentFlow(transactionType: PaymentFlowType) {
            switch transactionType {
            case .transaction(let transactionType):
                switch transactionType {
                case .erc1155Token(let token, let transferType, let tokenHolders):
                    startWithSendCollectiblesCoordinator(token: token, transferType: transferType, tokenHolders: tokenHolders)
                case .nativeCryptocurrency, .erc20Token, .dapp, .claimPaidErc875MagicLink, .tokenScript, .erc875TokenOrder, .prebuilt:
                    startWithSendCoordinator(transactionType: transactionType)
                case .erc875Token(let token, let tokenHolders), .erc721Token(let token, let tokenHolders):
                    startWithSendNFTCoordinator(transactionType: transactionType, token: token, tokenHolder: tokenHolders[0])
                case .erc721ForTicketToken(let token, let tokenHolders):
                    startWithSendNFTCoordinator(transactionType: transactionType, token: token, tokenHolder: tokenHolders[0])
                }
            case .tokenScript(let action, let token, let tokenHolder):
                startWithTokenScriptCoordinator(action: action, token: token, tokenHolder: tokenHolder)
            }
        }

        switch (flow, session.account.type) {
        case (.swap(let swapPair), .real):
            startWithSwapCoordinator(swapPair: swapPair)
        case (.send(let transactionType), .real):
            _startPaymentFlow(transactionType: transactionType)
        case (.request, _):
            let coordinator = RequestCoordinator(navigationController: navigationController, account: session.account, domainResolutionService: domainResolutionService)
            coordinator.delegate = self
            coordinator.start()
            addCoordinator(coordinator)
        case (.send(let transactionType), .watch):
            //TODO pass in a config instance instead
            if Config().development.shouldPretendIsRealWallet {
                _startPaymentFlow(transactionType: transactionType)
            } else {
                //TODO: This case should be returning an error inCoordinator. Improve this logic into single piece.
            }
        case (.swap(let swapPair), .watch):
            if Config().development.shouldPretendIsRealWallet {
                startWithSwapCoordinator(swapPair: swapPair)
            } else {
                //TODO: This case should be returning an error inCoordinator. Improve this logic into single piece.
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func dismiss(animated: Bool) {
        if shouldRestoreNavigationBarIsHiddenState {
            navigationController.setNavigationBarHidden(true, animated: false)
        }

        if let viewController = latestNavigationStackViewController {
            navigationController.popToViewController(viewController, animated: animated)
        } else {
            navigationController.popToRootViewController(animated: animated)
        }
    }
}

extension PaymentCoordinator: SwapTokensCoordinatorDelegate {

    func didFinish(_ result: ConfirmResult, in coordinator: SwapTokensCoordinator) {
        delegate?.didFinish(result, in: self)
    }

    func didSendTransaction(_ transaction: SentTransaction, in coordinator: SwapTokensCoordinator) {
        delegate?.didSendTransaction(transaction, inCoordinator: self)
    }

    func didCancel(in coordinator: SwapTokensCoordinator) {
        delegate?.didCancel(in: self)
    }
}

extension PaymentCoordinator: TransferNFTCoordinatorDelegate {

    func didFinish(_ result: ConfirmResult, in coordinator: TransferNFTCoordinator) {
        delegate?.didFinish(result, in: self)
    }

    func didCancel(in coordinator: TransferNFTCoordinator) {
        delegate?.didCancel(in: self)
    }
}

extension PaymentCoordinator: TokenScriptCoordinatorDelegate {
    func didFinish(_ result: ConfirmResult, in coordinator: TokenScriptCoordinator) {
        delegate?.didFinish(result, in: self)
    }

    func didCancel(in coordinator: TokenScriptCoordinator) {
        delegate?.didCancel(in: self)
    }
}

extension PaymentCoordinator: TransferCollectiblesCoordinatorDelegate {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator) {
        delegate?.didSendTransaction(transaction, inCoordinator: self)
    }

    func didSelectTokenHolder(tokenHolder: TokenHolder, in coordinator: TransferCollectiblesCoordinator) {
        delegate?.didSelectTokenHolder(tokenHolder: tokenHolder, in: self)
    }

    func didCancel(in coordinator: TransferCollectiblesCoordinator) {
        delegate?.didCancel(in: self)
    }

    func didFinish(_ result: ConfirmResult, in coordinator: TransferCollectiblesCoordinator) {
        delegate?.didFinish(result, in: self)
    }
}

extension PaymentCoordinator: SendCoordinatorDelegate {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: SendCoordinator) {
        delegate?.didSendTransaction(transaction, inCoordinator: self)
    }

    func didFinish(_ result: ConfirmResult, in coordinator: SendCoordinator) {
        delegate?.didFinish(result, in: self)
    }

    func didCancel(in coordinator: SendCoordinator) {
        delegate?.didCancel(in: self)
    }

    func buyCrypto(wallet: Wallet, server: RPCServer, viewController: UIViewController, source: Analytics.BuyCryptoSource) {
        delegate?.buyCrypto(wallet: wallet, server: server, viewController: viewController, source: source)
    }
}

extension PaymentCoordinator: RequestCoordinatorDelegate {
    func didCancel(in coordinator: RequestCoordinator) {
        delegate?.didCancel(in: self)
    }
}

extension PaymentCoordinator: CanOpenURL {
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
