//
//  WalletConnectToSessionCoordinatorBridgeToPromise.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.02.2021.
//

import PromiseKit

private class WalletConnectToSessionCoordinatorBridgeToPromise {

    private let (promiseToReturn, seal) = Promise<AlphaWallet.WalletConnect.ProposalResponse>.pending()
    private var retainCycle: WalletConnectToSessionCoordinatorBridgeToPromise?

    init(navigationController: UINavigationController, coordinator: Coordinator, proposal: AlphaWallet.WalletConnect.Proposal, serverChoices: [RPCServer], analyticsCoordinator: AnalyticsCoordinator, config: Config) {
        retainCycle = self

        let newCoordinator = WalletConnectToSessionCoordinator(analyticsCoordinator: analyticsCoordinator, proposal: proposal, navigationController: navigationController, serverChoices: serverChoices, config: config)
        newCoordinator.delegate = self
        coordinator.addCoordinator(newCoordinator)

        promiseToReturn.ensure {
            // ensure we break the retain cycle
            self.retainCycle = nil
            coordinator.removeCoordinator(newCoordinator)
        }.cauterize()

        newCoordinator.start()
    }

    var promise: Promise<AlphaWallet.WalletConnect.ProposalResponse> {
        return promiseToReturn
    }
}

extension WalletConnectToSessionCoordinatorBridgeToPromise: WalletConnectToSessionCoordinatorDelegate {
    func coordinator(_ coordinator: WalletConnectToSessionCoordinator, didCompleteWithConnection result: AlphaWallet.WalletConnect.ProposalResponse) {
        seal.fulfill(result)
    }
}

extension WalletConnectToSessionCoordinator {

    static func promise(_ navigationController: UINavigationController, coordinator: Coordinator, proposal: AlphaWallet.WalletConnect.Proposal, serverChoices: [RPCServer], analyticsCoordinator: AnalyticsCoordinator, config: Config) -> Promise<AlphaWallet.WalletConnect.ProposalResponse> {
        return WalletConnectToSessionCoordinatorBridgeToPromise(
            navigationController: navigationController,
            coordinator: coordinator,
            proposal: proposal,
            serverChoices: serverChoices,
            analyticsCoordinator: analyticsCoordinator,
            config: config
        ).promise
    }
}
