//
//  SignMessageCoordinatorBridgeToPromise.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.10.2020.
//

import UIKit
import PromiseKit

private class SignMessageCoordinatorBridgeToPromise {
    private let analyticsCoordinator: AnalyticsCoordinator
    private let navigationController: UINavigationController
    private let keystore: Keystore
    private let parentCoordinator: Coordinator
    private let source: Analytics.SignMessageRequestSource
    private weak var signMessageCoordinator: SignMessageCoordinator?
    private let (promise, seal) = Promise<Data>.pending()
    private var retainCycle: SignMessageCoordinatorBridgeToPromise?

    init(analyticsCoordinator: AnalyticsCoordinator, navigationController: UINavigationController, keystore: Keystore, coordinator: Coordinator, source: Analytics.SignMessageRequestSource) {
        self.analyticsCoordinator = analyticsCoordinator
        self.navigationController = navigationController
        self.keystore = keystore
        self.parentCoordinator = coordinator
        self.source = source

        retainCycle = self

        promise.ensure {
            // ensure we break the retain cycle
            self.retainCycle = nil

            if let coordinatorToRemove = coordinator.coordinators.first(where: { $0 === self.signMessageCoordinator }) {
                coordinator.removeCoordinator(coordinatorToRemove)
            }
        }.cauterize()
    }

    func promise(signType: SignMessageType, account: AlphaWallet.Address, walletConnectDappRequesterViewModel: WalletConnectDappRequesterViewModel?) -> Promise<Data> {
        let coordinator = SignMessageCoordinator(analyticsCoordinator: analyticsCoordinator, navigationController: navigationController, keystore: keystore, account: account, message: signType, source: source, walletConnectDappRequesterViewModel: walletConnectDappRequesterViewModel)
        coordinator.delegate = self
        coordinator.start()

        self.signMessageCoordinator = coordinator
        self.parentCoordinator.addCoordinator(coordinator)

        return promise
    }
}

extension SignMessageCoordinatorBridgeToPromise: SignMessageCoordinatorDelegate {
    func coordinator(_ coordinator: SignMessageCoordinator, didSign result: ResultResult<Data, KeystoreError>.t) {
        switch result {
        case .success(let data):
            seal.fulfill(data)
        case .failure:
            seal.reject(DAppError.cancelled)
        }
    }

    func didCancel(in coordinator: SignMessageCoordinator) {
        seal.reject(DAppError.cancelled)
    }
}

extension SignMessageCoordinator {
    static func promise(analyticsCoordinator: AnalyticsCoordinator, navigationController: UINavigationController, keystore: Keystore, coordinator: Coordinator, signType: SignMessageType, account: AlphaWallet.Address, source: Analytics.SignMessageRequestSource, walletConnectDappRequesterViewModel: WalletConnectDappRequesterViewModel?) -> Promise<Data> {
        let bridge = SignMessageCoordinatorBridgeToPromise(analyticsCoordinator: analyticsCoordinator, navigationController: navigationController, keystore: keystore, coordinator: coordinator, source: source)
        return bridge.promise(signType: signType, account: account, walletConnectDappRequesterViewModel: walletConnectDappRequesterViewModel)
    }
}
