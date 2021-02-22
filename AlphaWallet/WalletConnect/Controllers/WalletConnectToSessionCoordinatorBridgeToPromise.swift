//
//  WalletConnectToSessionCoordinatorBridgeToPromise.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.02.2021.
//

import PromiseKit

private class WalletConnectToSessionCoordinatorBridgeToPromise {

    private let (promiseToReturn, seal) = Promise<WalletConnectServer.ConnectionChoice>.pending()
    private var retainCycle: WalletConnectToSessionCoordinatorBridgeToPromise?

    init(navigationController: UINavigationController, coordinator: Coordinator, connection: WalletConnectConnection, serverChoices: [RPCServer]) {
        retainCycle = self

        let newCoordinator = WalletConnectToSessionCoordinator(connection: connection, navigationController: navigationController, serverChoices: serverChoices)
        newCoordinator.delegate = self
        coordinator.addCoordinator(newCoordinator)

        _ = promiseToReturn.ensure {
            // ensure we break the retain cycle
            self.retainCycle = nil
            coordinator.removeCoordinator(newCoordinator)
        }

        newCoordinator.start()
    }

    var promise: Promise<WalletConnectServer.ConnectionChoice> {
        return promiseToReturn
    }
}

extension WalletConnectToSessionCoordinatorBridgeToPromise: WalletConnectToSessionCoordinatorDelegate {
    func coordinator(_ coordinator: WalletConnectToSessionCoordinator, didCompleteWithConnection result: WalletConnectServer.ConnectionChoice) {
        seal.fulfill(result)
    }
}

extension WalletConnectToSessionCoordinator {

    static func promise(_ navigationController: UINavigationController, coordinator: Coordinator, connection: WalletConnectConnection, serverChoices: [RPCServer]) -> Promise<WalletConnectServer.ConnectionChoice> {
        return WalletConnectToSessionCoordinatorBridgeToPromise(
            navigationController: navigationController,
            coordinator: coordinator,
            connection: connection,
            serverChoices: serverChoices
        ).promise
    }
}
