//
//  TransactionInProgressCoordinatorBridgeToPromise.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 16.11.2020.
//

import UIKit
import PromiseKit

private class TransactionInProgressCoordinatorBridgeToPromise {

    private let (promiseToReturn, seal) = Promise<Void>.pending()
    private var retainCycle: TransactionInProgressCoordinatorBridgeToPromise?

    init(navigationController: UINavigationController, coordinator: Coordinator, account: Wallet) {
        retainCycle = self

        let newCoordinator = TransactionInProgressCoordinator(presentingViewController: navigationController, account: account)
        newCoordinator.delegate = self
        coordinator.addCoordinator(newCoordinator)

        promiseToReturn.ensure {
            // ensure we break the retain cycle
            self.retainCycle = nil
            coordinator.removeCoordinator(newCoordinator)
        }.cauterize()

        newCoordinator.start()
    }

    var promise: Promise<Void> {
        return promiseToReturn
    }
}

extension TransactionInProgressCoordinatorBridgeToPromise: TransactionInProgressCoordinatorDelegate {

    func transactionInProgressDidDismiss(in coordinator: TransactionInProgressCoordinator) {
        seal.fulfill(())
    }
}

extension TransactionInProgressCoordinator {

    static func promise(_ navigationController: UINavigationController, coordinator: Coordinator, account: Wallet) -> Promise<Void> {
        return TransactionInProgressCoordinatorBridgeToPromise(navigationController: navigationController, coordinator: coordinator, account: account).promise
    }
}
