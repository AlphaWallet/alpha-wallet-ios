//
//  TransactionConfirmationCoordinatorBridgeToPromise.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.10.2020.
//

import UIKit
import PromiseKit
import Result

protocol SendTransactionDelegate: class {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator)
}

protocol FiatOnRampDelegate: class {
    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TransactionConfirmationCoordinator, viewController: UIViewController)
}

typealias SendTransactionAndFiatOnRampDelegate = SendTransactionDelegate & FiatOnRampDelegate

private class TransactionConfirmationCoordinatorBridgeToPromise {
    private let analyticsCoordinator: AnalyticsCoordinator
    private let domainResolutionService: DomainResolutionServiceType
    private let navigationController: UINavigationController
    private let session: WalletSession
    private let coordinator: Coordinator & CanOpenURL
    private let (promise, seal) = Promise<ConfirmResult>.pending()
    private var retainCycle: TransactionConfirmationCoordinatorBridgeToPromise?
    private weak var confirmationCoordinator: TransactionConfirmationCoordinator?
    private weak var delegate: SendTransactionAndFiatOnRampDelegate?
    private let keystore: Keystore
    private let assetDefinitionStore: AssetDefinitionStore

    init(_ navigationController: UINavigationController, session: WalletSession, coordinator: Coordinator & CanOpenURL, analyticsCoordinator: AnalyticsCoordinator, domainResolutionService: DomainResolutionServiceType, delegate: SendTransactionAndFiatOnRampDelegate?, keystore: Keystore, assetDefinitionStore: AssetDefinitionStore) {
        self.navigationController = navigationController
        self.session = session
        self.coordinator = coordinator
        self.analyticsCoordinator = analyticsCoordinator
        self.domainResolutionService = domainResolutionService
        self.keystore = keystore
        self.assetDefinitionStore = assetDefinitionStore

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

    func promise(transaction: UnconfirmedTransaction, configuration: TransactionConfirmationViewModel.Configuration, source: Analytics.TransactionConfirmationSource) -> Promise<ConfirmResult> {
        do {
            let confirmationCoordinator = try TransactionConfirmationCoordinator(presentingViewController: navigationController, session: session, transaction: transaction, configuration: configuration, analyticsCoordinator: analyticsCoordinator, domainResolutionService: domainResolutionService, keystore: keystore, assetDefinitionStore: assetDefinitionStore)

            confirmationCoordinator.delegate = self
            self.confirmationCoordinator = confirmationCoordinator
            coordinator.addCoordinator(confirmationCoordinator)
            confirmationCoordinator.start(fromSource: source)
        } catch {
            UIApplication.shared
                .presentedViewController(or: navigationController)
                .displayError(message: error.prettyError)

            DispatchQueue.main.async {
                self.seal.reject(error)
            } 
        }

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

    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: AnyError) {
        coordinator.close {
            self.seal.reject(error)
        }
    }

    func didClose(in coordinator: TransactionConfirmationCoordinator) {
        seal.reject(DAppError.cancelled)
    }

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TransactionConfirmationCoordinator, viewController: UIViewController) {
        delegate?.openFiatOnRamp(wallet: wallet, server: server, inCoordinator: coordinator, viewController: viewController)
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
    static func promise(_ navigationController: UINavigationController, session: WalletSession, coordinator: Coordinator & CanOpenURL, transaction: UnconfirmedTransaction, configuration: TransactionConfirmationViewModel.Configuration, analyticsCoordinator: AnalyticsCoordinator, domainResolutionService: DomainResolutionServiceType, source: Analytics.TransactionConfirmationSource, delegate: SendTransactionAndFiatOnRampDelegate?, keystore: Keystore, assetDefinitionStore: AssetDefinitionStore) -> Promise<ConfirmResult> {
        let bridge = TransactionConfirmationCoordinatorBridgeToPromise(navigationController, session: session, coordinator: coordinator, analyticsCoordinator: analyticsCoordinator, domainResolutionService: domainResolutionService, delegate: delegate, keystore: keystore, assetDefinitionStore: assetDefinitionStore)
        return bridge.promise(transaction: transaction, configuration: configuration, source: source)
    }
}
