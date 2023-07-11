//
//  TransactionConfirmationCoordinatorBridgeToPromise.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.10.2020.
//

import UIKit
import PromiseKit
import AlphaWalletFoundation

protocol SendTransactionDelegate: AnyObject {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator)
}

protocol BuyCryptoDelegate: AnyObject {
    func buyCrypto(wallet: Wallet, server: RPCServer, viewController: UIViewController, source: Analytics.BuyCryptoSource)
}

typealias SendTransactionAndFiatOnRampDelegate = SendTransactionDelegate & BuyCryptoDelegate

private class TransactionConfirmationCoordinatorBridgeToPromise {
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainNameResolutionServiceType
    private let navigationController: UINavigationController
    private let session: WalletSession
    private let coordinator: Coordinator & CanOpenURL
    private let (promise, seal) = Promise<ConfirmResult>.pending()
    private var retainCycle: TransactionConfirmationCoordinatorBridgeToPromise?
    private weak var confirmationCoordinator: TransactionConfirmationCoordinator?
    private weak var delegate: SendTransactionAndFiatOnRampDelegate?
    private let keystore: Keystore
    private let tokensService: TokensProcessingPipeline
    private let networkService: NetworkService

    init(_ navigationController: UINavigationController,
         session: WalletSession,
         coordinator: Coordinator & CanOpenURL,
         analytics: AnalyticsLogger,
         domainResolutionService: DomainNameResolutionServiceType,
         delegate: SendTransactionAndFiatOnRampDelegate?,
         keystore: Keystore,
         tokensService: TokensProcessingPipeline,
         networkService: NetworkService) {

        self.networkService = networkService
        self.tokensService = tokensService
        self.navigationController = navigationController
        self.session = session
        self.coordinator = coordinator
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
        self.keystore = keystore

        retainCycle = self
        self.delegate = delegate

        promise.ensure {
            //NOTE: Ensure we break the retain cycle, and remove coordinator from list
            self.retainCycle = nil

            if let coordinatorToRemove = coordinator.coordinators.first(where: { $0 === self.confirmationCoordinator }) {
                coordinator.removeCoordinator(coordinatorToRemove)
            }
        }.cauterize()
    }

    func promise(transaction: UnconfirmedTransaction, configuration: TransactionType.Configuration, source: Analytics.TransactionConfirmationSource) -> Promise<ConfirmResult> {
        let confirmationCoordinator = TransactionConfirmationCoordinator(
            presentingViewController: navigationController,
            session: session,
            transaction: transaction,
            configuration: configuration,
            analytics: analytics,
            domainResolutionService: domainResolutionService,
            keystore: keystore,
            tokensService: tokensService,
            networkService: networkService)

        confirmationCoordinator.delegate = self
        self.confirmationCoordinator = confirmationCoordinator
        coordinator.addCoordinator(confirmationCoordinator)
        confirmationCoordinator.start(fromSource: source)

        return promise
    }
}

extension TransactionConfirmationCoordinatorBridgeToPromise: TransactionConfirmationCoordinatorDelegate {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator) {
        delegate?.didSendTransaction(transaction, inCoordinator: coordinator)
    }

    func didFinish(_ result: ConfirmResult, in coordinator: TransactionConfirmationCoordinator) {
        coordinator.close {
            self.seal.fulfill(result)
        }
    }

    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: Error) {
        coordinator.close {
            self.seal.reject(error)
        }
    }

    func didClose(in coordinator: TransactionConfirmationCoordinator) {
        seal.reject(JsonRpcError.requestRejected)
    }

    func buyCrypto(wallet: Wallet, server: RPCServer, viewController: UIViewController, source: Analytics.BuyCryptoSource) {
        delegate?.buyCrypto(wallet: wallet, server: server, viewController: viewController, source: source)
    }
}

extension TransactionConfirmationCoordinatorBridgeToPromise: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        coordinator.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        coordinator.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        coordinator.didPressOpenWebPage(url, in: viewController)
    }
}

extension TransactionConfirmationCoordinator {
    static func promise(_ navigationController: UINavigationController, session: WalletSession, coordinator: Coordinator & CanOpenURL, transaction: UnconfirmedTransaction, configuration: TransactionType.Configuration, analytics: AnalyticsLogger, domainResolutionService: DomainNameResolutionServiceType, source: Analytics.TransactionConfirmationSource, delegate: SendTransactionAndFiatOnRampDelegate?, keystore: Keystore, tokensService: TokensProcessingPipeline, networkService: NetworkService) -> Promise<ConfirmResult> {
        let bridge = TransactionConfirmationCoordinatorBridgeToPromise(
            navigationController,
            session: session,
            coordinator: coordinator,
            analytics: analytics,
            domainResolutionService: domainResolutionService,
            delegate: delegate,
            keystore: keystore,
            tokensService: tokensService,
            networkService: networkService)

        return bridge.promise(transaction: transaction, configuration: configuration, source: source)
    }
}
