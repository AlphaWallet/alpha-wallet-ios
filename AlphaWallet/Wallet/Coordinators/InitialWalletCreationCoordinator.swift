// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol InitialWalletCreationCoordinatorDelegate: AnyObject {
    func didCancel(in coordinator: InitialWalletCreationCoordinator)
    func didAddAccount(_ account: Wallet, in coordinator: InitialWalletCreationCoordinator)
}

class InitialWalletCreationCoordinator: Coordinator {
    private let keystore: Keystore
    private let config: Config
    private let analyticsCoordinator: AnalyticsCoordinator
    private let domainResolutionService: DomainResolutionServiceType

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: InitialWalletCreationCoordinatorDelegate?

    init(
        config: Config,
        navigationController: UINavigationController,
        keystore: Keystore,
        analyticsCoordinator: AnalyticsCoordinator,
        domainResolutionService: DomainResolutionServiceType
    ) {
        self.config = config
        self.navigationController = navigationController
        self.keystore = keystore
        self.analyticsCoordinator = analyticsCoordinator
        self.domainResolutionService = domainResolutionService

        navigationController.setNavigationBarHidden(false, animated: true)
    }

    func start() {
        startWalletCoordinator()
    }

    private func startWalletCoordinator() {
        let coordinator = WalletCoordinator(config: config, navigationController: navigationController, keystore: keystore, analyticsCoordinator: analyticsCoordinator, domainResolutionService: domainResolutionService)
        coordinator.delegate = self
        coordinator.start(.addInitialWallet)

        addCoordinator(coordinator)
    }
}

extension InitialWalletCreationCoordinator: WalletCoordinatorDelegate {
    func didFinish(with account: Wallet, in coordinator: WalletCoordinator) {
        navigationController.setNavigationBarHidden(true, animated: true)

        delegate?.didAddAccount(account, in: self)
        removeCoordinator(coordinator)
    }

    func didCancel(in coordinator: WalletCoordinator) {
        navigationController.setNavigationBarHidden(true, animated: true)

        delegate?.didCancel(in: self)
        removeCoordinator(coordinator)
    }
}
