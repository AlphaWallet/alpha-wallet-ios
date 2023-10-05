// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import Combine
import AlphaWalletCore
import AlphaWalletFoundation

protocol PaymentCoordinatorDelegate: CanOpenURL, BuyCryptoDelegate {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: PaymentCoordinator)
    func didFinish(_ result: ConfirmResult, in coordinator: PaymentCoordinator)
    func didCancel(in coordinator: PaymentCoordinator)
    func didSelectTokenHolder(tokenHolder: TokenHolder, in coordinator: PaymentCoordinator)
}

protocol NavigationBarPresentable {
    func willPush()
    func willPop()
}

class PaymentCoordinator: Coordinator {
    private var session: WalletSession {
        return sessionsProvider.session(for: server)!
    }
    private let server: RPCServer
    private let sessionsProvider: SessionsProvider
    private let keystore: Keystore
    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger
    private let tokensPipeline: TokensProcessingPipeline
    private let tokenSwapper: TokenSwapper
    private var shouldRestoreNavigationBarIsHiddenState: Bool
    private var latestNavigationStackViewController: UIViewController?
    private let reachabilityManager: ReachabilityManagerProtocol
    private let domainResolutionService: DomainNameResolutionServiceType
    private let tokensFilter: TokensFilter
    private let networkService: NetworkService
    private let transactionDataStore: TransactionDataStore
    private let tokenImageFetcher: TokenImageFetcher
    private let tokensService: TokensService

    let flow: PaymentFlow
    weak var delegate: PaymentCoordinatorDelegate?
    var coordinators: [Coordinator] = []
    let navigationController: UINavigationController

    init(navigationController: UINavigationController,
         flow: PaymentFlow,
         server: RPCServer,
         sessionsProvider: SessionsProvider,
         keystore: Keystore,
         assetDefinitionStore: AssetDefinitionStore,
         analytics: AnalyticsLogger,
         tokensPipeline: TokensProcessingPipeline,
         reachabilityManager: ReachabilityManagerProtocol = ReachabilityManager(),
         domainResolutionService: DomainNameResolutionServiceType,
         tokenSwapper: TokenSwapper,
         tokensFilter: TokensFilter,
         networkService: NetworkService,
         transactionDataStore: TransactionDataStore,
         tokenImageFetcher: TokenImageFetcher,
         tokensService: TokensService) {

        self.tokensService = tokensService
        self.tokenImageFetcher = tokenImageFetcher
        self.transactionDataStore = transactionDataStore
        self.networkService = networkService
        self.tokensFilter = tokensFilter
        self.tokenSwapper = tokenSwapper
        self.reachabilityManager = reachabilityManager
        self.tokensPipeline = tokensPipeline
        self.navigationController = navigationController
        self.server = server
        self.sessionsProvider = sessionsProvider
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
            sessionsProvider: sessionsProvider,
            keystore: keystore,
            tokensPipeline: tokensPipeline,
            assetDefinitionStore: assetDefinitionStore,
            analytics: analytics,
            domainResolutionService: domainResolutionService,
            networkService: networkService,
            tokenImageFetcher: tokenImageFetcher,
            tokensService: tokensService)

        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func startWithSendCollectiblesCoordinator(token: Token, tokenHolders: [TokenHolder]) {
        let coordinator = TransferCollectiblesCoordinator(
            session: session,
            navigationController: navigationController,
            keystore: keystore,
            filteredTokenHolders: tokenHolders,
            token: token,
            assetDefinitionStore: assetDefinitionStore,
            analytics: analytics,
            domainResolutionService: domainResolutionService,
            tokensService: tokensPipeline,
            networkService: networkService,
            tokenImageFetcher: tokenImageFetcher)

        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func startWithSendNFTCoordinator(transactionType: TransactionType, token: Token, tokenHolder: TokenHolder) {
        let coordinator = TransferNFTCoordinator(
            session: session,
            navigationController: navigationController,
            keystore: keystore,
            tokenHolder: tokenHolder,
            token: token,
            transactionType: transactionType,
            assetDefinitionStore: assetDefinitionStore,
            analytics: analytics,
            domainResolutionService: domainResolutionService,
            tokensService: tokensPipeline,
            networkService: networkService,
            tokenImageFetcher: tokenImageFetcher)

        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func startWithTokenScriptCoordinator(action: TokenInstanceAction, token: Token, tokenHolder: TokenHolder) {
        let coordinator = TokenScriptCoordinator(
            session: session,
            navigationController: navigationController,
            keystore: keystore,
            tokenHolder: tokenHolder,
            tokenObject: token,
            assetDefinitionStore: assetDefinitionStore,
            analytics: analytics,
            domainResolutionService: domainResolutionService,
            action: action,
            tokensService: tokensPipeline,
            networkService: networkService)

        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func startWithSwapCoordinator(swapPair: SwapPair) {
        let configurator = SwapOptionsConfigurator(
            sessionProvider: sessionsProvider,
            swapPair: swapPair,
            tokensService: tokensService,
            tokenSwapper: tokenSwapper)

        let coordinator = SwapTokensCoordinator(
            navigationController: navigationController,
            configurator: configurator,
            keystore: keystore,
            analytics: analytics,
            domainResolutionService: domainResolutionService,
            assetDefinitionStore: assetDefinitionStore,
            tokensPipeline: tokensPipeline,
            tokensFilter: tokensFilter,
            networkService: networkService,
            transactionDataStore: transactionDataStore,
            tokenImageFetcher: tokenImageFetcher,
            tokensService: tokensService)

        coordinator.start()
        coordinator.delegate = self
        addCoordinator(coordinator)
    }

    func start() {
        if let navigationBar = navigationController.navigationBar as? NavigationBarPresentable {
            navigationBar.willPush()
        }

        if shouldRestoreNavigationBarIsHiddenState {
            navigationController.setNavigationBarHidden(false, animated: false)
        }

        func _startPaymentFlow(paymentFlowType: PaymentFlowType) {
            switch paymentFlowType {
            case .transaction(let transactionType):
                switch transactionType {
                case .erc1155Token(let token, let tokenHolders):
                    startWithSendCollectiblesCoordinator(token: token, tokenHolders: tokenHolders)
                case .nativeCryptocurrency, .erc20Token, .prebuilt:
                    startWithSendCoordinator(transactionType: transactionType)
                case .erc721ForTicketToken(let token, let tokenHolders), .erc875Token(let token, let tokenHolders), .erc721Token(let token, let tokenHolders):
                    startWithSendNFTCoordinator(transactionType: transactionType, token: token, tokenHolder: tokenHolders[0])
                }
            case .tokenScript(let action, let token, let tokenHolder):
                startWithTokenScriptCoordinator(action: action, token: token, tokenHolder: tokenHolder)
            }
        }

        switch (flow, session.account.type) {
        case (.swap(let swapPair), .real), (.swap(let swapPair), .hardware):
            startWithSwapCoordinator(swapPair: swapPair)
        case (.send(let paymentFlowType), .real), (.send(let paymentFlowType), .hardware):
            _startPaymentFlow(paymentFlowType: paymentFlowType)
        case (.request, _):
            let coordinator = RequestCoordinator(
                navigationController: navigationController,
                account: session.account,
                domainResolutionService: domainResolutionService)
            coordinator.delegate = self
            coordinator.start()
            addCoordinator(coordinator)
        case (.send(let paymentFlowType), .watch):
            //TODO pass in a config instance instead
            if Config().development.shouldPretendIsRealWallet {
                _startPaymentFlow(paymentFlowType: paymentFlowType)
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
        if let navigationBar = navigationController.navigationBar as? NavigationBarPresentable {
            navigationBar.willPop()
        }

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
    func didSelectTokenHolder(tokenHolder: AlphaWalletFoundation.TokenHolder, in coordinator: TransferNFTCoordinator) {
        delegate?.didSelectTokenHolder(tokenHolder: tokenHolder, in: self)
    }

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
