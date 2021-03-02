//
//  TransactionConfirmationCoordinatorBridgeToPromise.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.10.2020.
//

import UIKit
import PromiseKit
import Result

private class TransactionConfirmationCoordinatorBridgeToPromise {
    private let analyticsCoordinator: AnalyticsCoordinator
    private let navigationController: UINavigationController
    private let session: WalletSession
    private let coordinator: Coordinator
    private let (promise, seal) = Promise<ConfirmResult>.pending()
    private var retainCycle: TransactionConfirmationCoordinatorBridgeToPromise?

    init(_ navigationController: UINavigationController, session: WalletSession, coordinator: Coordinator, analyticsCoordinator: AnalyticsCoordinator) {
        self.navigationController = navigationController
        self.session = session
        self.coordinator = coordinator
        self.analyticsCoordinator = analyticsCoordinator
        retainCycle = self

        promise.ensure {
            //NOTE: Ensure we break the retain cycle, and remove coordinator from list
            self.retainCycle = nil

            if let coordinatorToRemove = coordinator.coordinators.first(where: { $0 is TransactionConfirmationCoordinator }) {
                coordinator.removeCoordinator(coordinatorToRemove)
            }
        }.cauterize()
    }

    func promise(account: AlphaWallet.Address, transaction: UnconfirmedTransaction, configuration: TransactionConfirmationConfiguration, source: Analytics.TransactionConfirmationSource) -> Promise<ConfirmResult> {
        let confirmationCoordinator = TransactionConfirmationCoordinator(navigationController: navigationController, session: session, transaction: transaction, configuration: configuration, analyticsCoordinator: analyticsCoordinator)

        confirmationCoordinator.delegate = self
        coordinator.addCoordinator(confirmationCoordinator)
        confirmationCoordinator.start(fromSource: source)

        return promise
    }
}

extension TransactionConfirmationCoordinatorBridgeToPromise: TransactionConfirmationCoordinatorDelegate {

    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didCompleteTransaction result: TransactionConfirmationResult) {
        coordinator.close().done { _ in
            switch result {
            case .confirmationResult(let value):
                self.seal.fulfill(value)
            case .noData:
                self.seal.reject(DAppError.cancelled)
            }
        }.cauterize()
    }

    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: AnyError) {
        coordinator.close().done { _ in
            //no op
        }.ensure {
            self.seal.reject(error)
        }.cauterize()
    }

    func didClose(in coordinator: TransactionConfirmationCoordinator) {
        seal.reject(DAppError.cancelled)
    }
}

extension UIViewController {

    func displayErrorPromise(message: String) -> Promise<Void> {
        let (promise, seal) = Promise<Void>.pending()

        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.popoverPresentationController?.sourceView = view
        let action = UIAlertAction(title: R.string.localizable.oK(), style: .default) { _ in
            seal.fulfill(())
        }

        alertController.addAction(action)

        present(alertController, animated: true)

        return promise
    }
}

extension TransactionConfirmationCoordinator {

    //session contains account already
    static func promise(_ navigationController: UINavigationController, session: WalletSession, coordinator: Coordinator, account: AlphaWallet.Address, transaction: UnconfirmedTransaction, configuration: TransactionConfirmationConfiguration, analyticsCoordinator: AnalyticsCoordinator, source: Analytics.TransactionConfirmationSource) -> Promise<ConfirmResult> {
        let bridge = TransactionConfirmationCoordinatorBridgeToPromise(navigationController, session: session, coordinator: coordinator, analyticsCoordinator: analyticsCoordinator)
        return bridge.promise(account: account, transaction: transaction, configuration: configuration, source: source)
    }
}
