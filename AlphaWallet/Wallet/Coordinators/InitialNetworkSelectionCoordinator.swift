//
//  InitialNetworkSelectionCoordinator.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 9/5/22.
//

import UIKit

protocol InitialNetworkSelectionCoordinatorDelegateProtocol: class {
    func didSelect(networks: [RPCServer], in coordinator: InitialNetworkSelectionCoordinator)
}

class InitialNetworkSelectionCoordinator: Coordinator {
    var coordinators: [Coordinator] = []
    var navigationController: UINavigationController
    var config: Config
    weak var delegate: InitialNetworkSelectionCoordinatorDelegateProtocol?

    init(config: Config, navigationController: UINavigationController) {
        self.navigationController = navigationController
        self.config = config
        navigationController.setNavigationBarHidden(false, animated: true)
    }

    func start() {
        let controller = InitialNetworkSelectionViewController(model: InitialNetworkSelectionCollectionModel(servers: RPCServer.allCases, selected: Set<RPCServer>(config.enabledServers)))
        controller.delegate = self
        navigationController.viewControllers = [controller]
        // We create the view controller here and wait for the user to select something
//        let controller = CreateInitialWalletViewController(keystore: keystore)
//        controller.delegate = self
//        controller.configure()
//        navigationController.viewControllers = [controller]
    }
}

extension InitialNetworkSelectionCoordinator: InitialNetworkSelectionViewControllerDelegateProtocol {
    func didSelect(networks: [RPCServer], in viewController: InitialNetworkSelectionViewController) {
        // FIXME: Do we need to do anything to the viewController
        delegate?.didSelect(networks: networks, in: self)
    }
}
