// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol PaymentCoordinatorDelegate: class, CanOpenURL {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: PaymentCoordinator)
    func didFinish(_ result: ConfirmResult, in coordinator: PaymentCoordinator)
    func didCancel(in coordinator: PaymentCoordinator)
    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: PaymentCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource)
    func didSelectTokenHolder(tokenHolder: TokenHolder, in coordinator: PaymentCoordinator)
}

class PaymentCoordinator: Coordinator {
    private let session: WalletSession
    let flow: PaymentFlow
    private let keystore: Keystore
    private let tokensStorage: TokensDataStore
    private let ethPrice: Subscribable<Double>
    private let assetDefinitionStore: AssetDefinitionStore
    private let analyticsCoordinator: AnalyticsCoordinator
    private let eventsDataStore: EventsDataStoreProtocol
    weak var delegate: PaymentCoordinatorDelegate?
    var coordinators: [Coordinator] = []
    let navigationController: UINavigationController

    private var shouldRestoreNavigationBarIsHiddenState: Bool
    private var latestNavigationStackViewController: UIViewController?

    init(
            navigationController: UINavigationController,
            flow: PaymentFlow,
            session: WalletSession,
            keystore: Keystore,
            tokensStorage: TokensDataStore,
            ethPrice: Subscribable<Double>,
            assetDefinitionStore: AssetDefinitionStore,
            analyticsCoordinator: AnalyticsCoordinator,
            eventsDataStore: EventsDataStoreProtocol
    ) {
        self.navigationController = navigationController
        self.session = session
        self.flow = flow
        self.keystore = keystore
        self.tokensStorage = tokensStorage
        self.ethPrice = ethPrice
        self.assetDefinitionStore = assetDefinitionStore
        self.analyticsCoordinator = analyticsCoordinator
        self.eventsDataStore = eventsDataStore

        shouldRestoreNavigationBarIsHiddenState = navigationController.navigationBar.isHidden
        latestNavigationStackViewController = navigationController.viewControllers.last
    }

    private func startWithSendCoordinator(transactionType: TransactionType) {
        let coordinator = SendCoordinator(
            transactionType: transactionType,
            navigationController: navigationController,
            session: session,
            keystore: keystore,
            storage: tokensStorage,
            ethPrice: ethPrice,
            assetDefinitionStore: assetDefinitionStore,
            analyticsCoordinator: analyticsCoordinator
        )
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func startWithSendCollectiblesCoordinator(tokenObject: TokenObject, transferType: Erc1155TokenTransactionType, tokenHolders: [TokenHolder]) {
        let coordinator = TransferCollectiblesCoordinator(session: session, navigationController: navigationController, keystore: keystore, filteredTokenHolders: tokenHolders, tokensStorage: tokensStorage, ethPrice: ethPrice, tokenObject: tokenObject, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func startWithSendNFTCoordinator(transactionType: TransactionType, tokenObject: TokenObject, tokenHolder: TokenHolder) {
        let coordinator = TransferNFTCoordinator(session: session, navigationController: navigationController, keystore: keystore, tokenHolder: tokenHolder, tokensStorage: tokensStorage, ethPrice: ethPrice, tokenObject: tokenObject, transactionType: transactionType, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    private func startWithTokenScriptCoordinator(action: TokenInstanceAction, tokenObject: TokenObject, tokenHolder: TokenHolder) {
        let coordinator = TokenScriptCoordinator(session: session, navigationController: navigationController, keystore: keystore, tokenHolder: tokenHolder, tokensStorage: tokensStorage, ethPrice: ethPrice, tokenObject: tokenObject, assetDefinitionStore: assetDefinitionStore, analyticsCoordinator: analyticsCoordinator, action: action, eventsDataStore: eventsDataStore)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }

    func start() {
        if shouldRestoreNavigationBarIsHiddenState {
            self.navigationController.setNavigationBarHidden(false, animated: true)
        }

        switch (flow, session.account.type) {
        case (.send(let transactionType), .real):
            switch transactionType {
            case .transaction(let transactionType):
                switch transactionType {
                case .erc1155Token(let tokenObject, let transferType, let tokenHolders):
                    startWithSendCollectiblesCoordinator(tokenObject: tokenObject, transferType: transferType, tokenHolders: tokenHolders)
                case .nativeCryptocurrency, .erc20Token, .dapp, .claimPaidErc875MagicLink, .tokenScript, .erc875TokenOrder:
                    startWithSendCoordinator(transactionType: transactionType)
                case .erc875Token(let tokenObject, let tokenHolders), .erc721Token(let tokenObject, let tokenHolders):
                    startWithSendNFTCoordinator(transactionType: transactionType, tokenObject: tokenObject, tokenHolder: tokenHolders[0])
                case .erc721ForTicketToken(let tokenObject, let tokenHolders):
                    startWithSendNFTCoordinator(transactionType: transactionType, tokenObject: tokenObject, tokenHolder: tokenHolders[0])
                }
            case .tokenScript(let action, let tokenObject, let tokenHolder):
                startWithTokenScriptCoordinator(action: action, tokenObject: tokenObject, tokenHolder: tokenHolder)
            }
        case (.request, _):
            let coordinator = RequestCoordinator(navigationController: navigationController, account: session.account)
            coordinator.delegate = self
            coordinator.start()
            addCoordinator(coordinator)
        case (.send, .watch):
            // This case should be returning an error inCoordinator. Improve this logic into single piece.
            break
        }
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func cancel() {
        delegate?.didCancel(in: self)
    }

    func dismiss(animated: Bool) {
        if shouldRestoreNavigationBarIsHiddenState {
            navigationController.setNavigationBarHidden(true, animated: animated)
        }

        if let viewController = latestNavigationStackViewController {
            navigationController.popToViewController(viewController, animated: animated)
        } else {
            navigationController.popToRootViewController(animated: animated)
        }
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
        removeCoordinator(coordinator)
        cancel()
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
        removeCoordinator(coordinator)
        cancel()
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
        removeCoordinator(coordinator)
        cancel()
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
        removeCoordinator(coordinator)
        cancel()
    }

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: SendCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource) {
        delegate?.openFiatOnRamp(wallet: wallet, server: server, inCoordinator: self, viewController: viewController, source: source)
    }
}

extension PaymentCoordinator: RequestCoordinatorDelegate {
    func didCancel(in coordinator: RequestCoordinator) {
        removeCoordinator(coordinator)
        cancel()
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
