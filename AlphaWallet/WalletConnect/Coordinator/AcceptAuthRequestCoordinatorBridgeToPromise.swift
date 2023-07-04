// Copyright © 2023 Stormbird PTE. LTD.

import AlphaWalletFoundation
import PromiseKit

private class AcceptAuthRequestCoordinatorBridgeToPromise {
    private let (promiseToReturn, seal) = Promise<AuthRequestResult>.pending()
    private var retainCycle: AcceptAuthRequestCoordinatorBridgeToPromise?

    init(navigationController: UINavigationController, coordinator: Coordinator, authRequest: AlphaWallet.WalletConnect.AuthRequest, analytics: AnalyticsLogger) {
        retainCycle = self

        let newCoordinator = AcceptAuthRequestCoordinator(analytics: analytics, authRequest: authRequest, navigationController: navigationController)
        newCoordinator.delegate = self
        coordinator.addCoordinator(newCoordinator)

        promiseToReturn.ensure {
            // ensure we break the retain cycle
            self.retainCycle = nil
            coordinator.removeCoordinator(newCoordinator)
        }.cauterize()

        newCoordinator.start()
    }

    var promise: Promise<AuthRequestResult> {
        return promiseToReturn
    }
}

extension AcceptAuthRequestCoordinatorBridgeToPromise: AcceptAuthRequestCoordinatorDelegate {
    func coordinator(_ coordinator: AcceptAuthRequestCoordinator, didComplete result: AuthRequestResult) {
        seal.fulfill(result)
    }
}

extension AcceptAuthRequestCoordinator {
    static func promise(_ navigationController: UINavigationController, coordinator: Coordinator, authRequest: AlphaWallet.WalletConnect.AuthRequest, analytics: AnalyticsLogger) -> Promise<AuthRequestResult> {
        return AcceptAuthRequestCoordinatorBridgeToPromise(navigationController: navigationController, coordinator: coordinator, authRequest: authRequest, analytics: analytics).promise
    }
}
