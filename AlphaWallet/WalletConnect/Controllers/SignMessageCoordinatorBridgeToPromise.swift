//
//  SignMessageCoordinatorBridgeToPromise.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.10.2020.
//

import UIKit
import PromiseKit

private class SignMessageCoordinatorBridgeToPromise {

    private let navigationController: UINavigationController
    private let keystore: Keystore
    private let coordinator: Coordinator
    private let (promise, seal) = Promise<Data>.pending()
    private var retainCycle: SignMessageCoordinatorBridgeToPromise?

    init(_ navigationController: UINavigationController, keystore: Keystore, coordinator: Coordinator) {
        self.navigationController = navigationController
        self.keystore = keystore
        self.coordinator = coordinator

        retainCycle = self

        _ = promise.ensure {
            // ensure we break the retain cycle
            self.retainCycle = nil

            if let coordinatorToRemove = coordinator.coordinators.first(where: { $0 is SignMessageCoordinator }) {
                coordinator.removeCoordinator(coordinatorToRemove)
            }
        }
    }

    func promise(signType: SignMessageType, account: AlphaWallet.Address) -> Promise<Data> {
        let coordinator = SignMessageCoordinator(navigationController: navigationController, keystore: keystore, account: account)
        self.coordinator.addCoordinator(coordinator)

        coordinator.didComplete = { result in
            switch result {
            case .success(let data):
                self.seal.fulfill(data)
            case .failure:
                self.seal.reject(DAppError.cancelled)
            }

            coordinator.didComplete = nil
        }

        coordinator.start(with: signType)

        return promise
    }
}

extension SignMessageCoordinator {
    static func promise(_ navigationController: UINavigationController, keystore: Keystore, coordinator: Coordinator, signType: SignMessageType, account: AlphaWallet.Address) -> Promise<Data> {
        let bridge = SignMessageCoordinatorBridgeToPromise(navigationController, keystore: keystore, coordinator: coordinator)
        return bridge.promise(signType: signType, account: account)
    }
}
