//
//  InitialNetworkSelectionCoordinator.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 9/5/22.
//

import UIKit
import AlphaWalletFoundation

protocol InitialNetworkSelectionCoordinatorDelegate: class {
    func didSelect(networks: [RPCServer], in coordinator: InitialNetworkSelectionCoordinator)
}

class InitialNetworkSelectionCoordinator: Coordinator {
    var coordinators: [Coordinator] = []
    var navigationController: UINavigationController
    var config: Config
    var restartTaskQueue: RestartTaskQueue
    weak var delegate: InitialNetworkSelectionCoordinatorDelegate?

    init(config: Config, navigationController: UINavigationController, restartTaskQueue: RestartTaskQueue) {
        self.navigationController = navigationController
        self.config = config
        self.restartTaskQueue = restartTaskQueue
        navigationController.setNavigationBarHidden(false, animated: true)
    }

    func start() {
        let controller = InitialNetworkSelectionViewController(model: InitialNetworkSelectionCollectionModel(servers: EnabledServersCoordinator.serversOrdered))
        controller.delegate = self
        navigationController.viewControllers = [controller]
    }
}

extension InitialNetworkSelectionCoordinator: InitialNetworkSelectionViewControllerDelegate {
    func didSelect(servers: [RPCServer], in viewController: InitialNetworkSelectionViewController) {
        viewController.dismiss(animated: true)
        config.enabledServers = servers
        delegate?.didSelect(networks: servers, in: self)
    }
}
