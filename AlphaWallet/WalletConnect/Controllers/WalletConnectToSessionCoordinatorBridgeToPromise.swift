//
//  AcceptProposalCoordinatorBridgeToPromise.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.02.2021.
//

import PromiseKit

private class AcceptProposalCoordinatorBridgeToPromise {

    private let (promiseToReturn, seal) = Promise<ProposalResult>.pending()
    private var retainCycle: AcceptProposalCoordinatorBridgeToPromise?

    init(navigationController: UINavigationController, coordinator: Coordinator, proposalType: ProposalType, analyticsCoordinator: AnalyticsCoordinator) {
        retainCycle = self

        let newCoordinator = AcceptProposalCoordinator(analyticsCoordinator: analyticsCoordinator, proposalType: proposalType, navigationController: navigationController)
        newCoordinator.delegate = self
        coordinator.addCoordinator(newCoordinator)

        promiseToReturn.ensure {
            // ensure we break the retain cycle
            self.retainCycle = nil
            coordinator.removeCoordinator(newCoordinator)
        }.cauterize()

        newCoordinator.start()
    }

    var promise: Promise<ProposalResult> {
        return promiseToReturn
    }
}

extension AcceptProposalCoordinatorBridgeToPromise: AcceptProposalCoordinatorDelegate {
    func coordinator(_ coordinator: AcceptProposalCoordinator, didComplete result: ProposalResult) {
        seal.fulfill(result)
    }
}

extension AcceptProposalCoordinator {

    static func promise(_ navigationController: UINavigationController, coordinator: Coordinator, proposalType: ProposalType, analyticsCoordinator: AnalyticsCoordinator) -> Promise<ProposalResult> {
        return AcceptProposalCoordinatorBridgeToPromise(navigationController: navigationController, coordinator: coordinator, proposalType: proposalType, analyticsCoordinator: analyticsCoordinator).promise
    }
}
