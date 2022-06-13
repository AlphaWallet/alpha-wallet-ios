// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import Combine

protocol PaymentCoordinatorDelegate: class, CanOpenURL {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: PaymentCoordinator)
    func didFinish(_ result: ConfirmResult, in coordinator: PaymentCoordinator)
    func didCancel(in coordinator: PaymentCoordinator)
    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: PaymentCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource)
    func didSelectTokenHolder(tokenHolder: TokenHolder, in coordinator: PaymentCoordinator)
}

class PaymentCoordinator: Coordinator {
    private var session: WalletSession {
        sessions.value[server]
    }
    private let server: RPCServer
    private let sessions: CurrentValueSubject<ServerDictionary<WalletSession>, Never>
    private let keystore: Keystore
    private let tokensDataStore: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let analyticsCoordinator: AnalyticsCoordinator
    private let eventsDataStore: NonActivityEventsDataStore
    private let tokenCollection: TokenCollection
    private let tokenSwapper: TokenSwapper
    private var shouldRestoreNavigationBarIsHiddenState: Bool
    private var latestNavigationStackViewController: UIViewController?
    private let reachabilityManager: ReachabilityManagerProtocol
    private let domainResolutionService: DomainResolutionServiceType

    let flow: PaymentFlow
    weak var delegate: PaymentCoordinatorDelegate?
    var coordinators: [Coordinator] = []
    let navigationController: UINavigationController

    init(
            navigationController: UINavigationController,
            flow: PaymentFlow,
            server: RPCServer,
            sessions: CurrentValueSubject<ServerDictionary<WalletSession>, Never>,
            keystore: Keystore,
            tokensDataStore: TokensDataStore,
            assetDefinitionStore: AssetDefinitionStore,
            analyticsCoordinator: AnalyticsCoordinator,
            eventsDataStore: NonActivityEventsDataStore,
            tokenCollection: TokenCollection,
            reachabilityManager: ReachabilityManagerProtocol = ReachabilityManager(),
            domainResolutionService: DomainResolutionServiceType,
            tokenSwapper: TokenSwapper
    ) {
        self.tokenSwapper = tokenSwapper
        self.reachabilityManager = reachabilityManager
        self.tokenCollection = tokenCollection
        self.navigationController = navigationController
        self.server = server
        self.sessions = sessions
        self.flow = flow
        self.keystore = keystore
        self.tokensDataStore = tokensDataStore
        self.assetDefinitionStore = assetDefinitionStore
        self.analyticsCoordinator = analyticsCoordinator
        self.eventsDataStore = eventsDataStore
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
            tokensDataStore: tokensDataStore,
            assetDefinitionStore: assetDefinitionStore,
            analyticsCoordinator: analyticsCoordinator,
            domainResolutionService: domainResolutionService
        )
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func startWithSendCollectiblesCoordinator(tokenObject: TokenObject, transferType: Erc1155TokenTransactionType, tokenHolders: [TokenHolder]) {
        let coordinator = TransferCollectiblesCoordinator(session: session, navigationController: navigationController, keystore: keystore, filteredTokenHolders: tokenHolders, tokenObject: tokenObject, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, domainResolutionService: domainResolutionService)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func startWithSendNFTCoordinator(transactionType: TransactionType, tokenObject: TokenObject, tokenHolder: TokenHolder) {
        let coordinator = TransferNFTCoordinator(session: session, navigationController: navigationController, keystore: keystore, tokenHolder: tokenHolder, tokenObject: tokenObject, transactionType: transactionType, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, domainResolutionService: domainResolutionService)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func startWithTokenScriptCoordinator(action: TokenInstanceAction, tokenObject: TokenObject, tokenHolder: TokenHolder) {
        let coordinator = TokenScriptCoordinator(session: session, navigationController: navigationController, keystore: keystore, tokenHolder: tokenHolder, tokensStorage: tokensDataStore, tokenObject: tokenObject, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, domainResolutionService: domainResolutionService, action: action, eventsDataStore: eventsDataStore)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func startWithSwapCoordinator(swapPair: SwapPair) {
        let configurator = SwapOptionsConfigurator(walletSessions: sessions, swapPair: swapPair, tokenCollection: tokenCollection, reachabilityManager: reachabilityManager, tokenSwapper: tokenSwapper)
        let coordinator = SwapTokensCoordinator(navigationController: navigationController, configurator: configurator, keystore: keystore, analyticsCoordinator: analyticsCoordinator, domainResolutionService: domainResolutionService, assetDefinitionStore: assetDefinitionStore, tokenCollection: tokenCollection, eventsDataStore: eventsDataStore)
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
                case .erc1155Token(let tokenObject, let transferType, let tokenHolders):
                    startWithSendCollectiblesCoordinator(tokenObject: tokenObject, transferType: transferType, tokenHolders: tokenHolders)
                case .nativeCryptocurrency, .erc20Token, .dapp, .claimPaidErc875MagicLink, .tokenScript, .erc875TokenOrder, .prebuilt:
                    startWithSendCoordinator(transactionType: transactionType)
                case .erc875Token(let tokenObject, let tokenHolders), .erc721Token(let tokenObject, let tokenHolders):
                    startWithSendNFTCoordinator(transactionType: transactionType, tokenObject: tokenObject, tokenHolder: tokenHolders[0])
                case .erc721ForTicketToken(let tokenObject, let tokenHolders):
                    startWithSendNFTCoordinator(transactionType: transactionType, tokenObject: tokenObject, tokenHolder: tokenHolders[0])
                }
            case .tokenScript(let action, let tokenObject, let tokenHolder):
                startWithTokenScriptCoordinator(action: action, tokenObject: tokenObject, tokenHolder: tokenHolder)
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

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, coordinator: SwapTokensCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource) {
        delegate?.openFiatOnRamp(wallet: wallet, server: server, inCoordinator: self, viewController: viewController, source: source)
    }

    func didCancel(in coordinator: SwapTokensCoordinator) {
        delegate?.didCancel(in: self)
    }
}

extension PaymentCoordinator: TransferNFTCoordinatorDelegate {

    func didFinish(_ result: ConfirmResult, in coordinator: TransferNFTCoordinator) {
        delegate?.didFinish(result, in: self)
    }

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TransferNFTCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource) {
        delegate?.openFiatOnRamp(wallet: wallet, server: server, inCoordinator: self, viewController: viewController, source: source)
    }

    func didCancel(in coordinator: TransferNFTCoordinator) {
        delegate?.didCancel(in: self)
    }
}

extension PaymentCoordinator: TokenScriptCoordinatorDelegate {
    func didFinish(_ result: ConfirmResult, in coordinator: TokenScriptCoordinator) {
        delegate?.didFinish(result, in: self)
    }

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TokenScriptCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource) {
        delegate?.openFiatOnRamp(wallet: wallet, server: server, inCoordinator: self, viewController: viewController, source: source)
    }

    func didCancel(in coordinator: TokenScriptCoordinator) {
        delegate?.didCancel(in: self)
    }
}

extension PaymentCoordinator: TransferCollectiblesCoordinatorDelegate {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator) {
        delegate?.didSendTransaction(transaction, inCoordinator: self)
    }

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TransferCollectiblesCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource) {
        delegate?.openFiatOnRamp(wallet: wallet, server: server, inCoordinator: self, viewController: viewController, source: source)
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

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: SendCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource) {
        delegate?.openFiatOnRamp(wallet: wallet, server: server, inCoordinator: self, viewController: viewController, source: source)
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
