// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol EnabledServersCoordinatorDelegate: AnyObject {
    func restartToReloadServersQueued(in coordinator: EnabledServersCoordinator)
}

class EnabledServersCoordinator: Coordinator {
    //Cannot be `let` as the chains can change dynamically without the app being restarted (i.e. killed). The UI can be restarted though (when switching changes)
    static var serversOrdered: [RPCServer] {
        ServersCoordinator.serversOrdered
    }

    private let serverChoices = EnabledServersCoordinator.serversOrdered
    private let navigationController: UINavigationController
    private let selectedServers: [RPCServer]
    private let restartQueue: RestartTaskQueue
    private let analytics: AnalyticsLogger
    private let config: Config
    private let networkService: NetworkService
    private lazy var enabledServersViewController: EnabledServersViewController = {
        let viewModel = EnabledServersViewModel(
            servers: serverChoices,
            selectedServers: selectedServers,
            restartQueue: restartQueue,
            config: config)
        
        let controller = EnabledServersViewController(viewModel: viewModel)
        controller.delegate = self
        controller.hidesBottomBarWhenPushed = true
        controller.navigationItem.rightBarButtonItem = .addBarButton(self, selector: #selector(addRPCSelected))

        return controller
    }()

    var coordinators: [Coordinator] = []
    weak var delegate: EnabledServersCoordinatorDelegate?

    init(navigationController: UINavigationController,
         selectedServers: [RPCServer],
         restartQueue: RestartTaskQueue,
         analytics: AnalyticsLogger,
         config: Config,
         networkService: NetworkService) {

        self.networkService = networkService
        self.navigationController = navigationController
        self.selectedServers = selectedServers
        self.restartQueue = restartQueue
        self.analytics = analytics
        self.config = config
    }

    func start() {
        enabledServersViewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(enabledServersViewController, animated: true)
    }

    @objc private func addRPCSelected() {
        let coordinator = SaveCustomRpcCoordinator(
            navigationController: navigationController,
            config: config,
            restartQueue: restartQueue,
            analytics: analytics,
            operation: .add,
            networkService: networkService)
        addCoordinator(coordinator)
        coordinator.delegate = self

        coordinator.start()
    }
    
    private func edit(customRpc: CustomRPC, in viewController: EnabledServersViewController) {
        let coordinator = SaveCustomRpcCoordinator(
            navigationController: navigationController,
            config: config,
            restartQueue: restartQueue,
            analytics: analytics,
            operation: .edit(customRpc),
            networkService: networkService)

        addCoordinator(coordinator)
        coordinator.delegate = self

        coordinator.start()
    }
}

extension EnabledServersCoordinator: EnabledServersViewControllerDelegate {

    func notifyReloadServersQueued(in viewController: EnabledServersViewController) {
        delegate?.restartToReloadServersQueued(in: self)
    }

    func didEditSelectedServer(customRpc: CustomRPC, in viewController: EnabledServersViewController) {
        self.edit(customRpc: customRpc, in: viewController)
    }
}

extension EnabledServersCoordinator: SaveCustomRpcCoordinatorDelegate {
    func didDismiss(in coordinator: SaveCustomRpcCoordinator) {
        removeCoordinator(coordinator)
    }

    func restartToEdit(in coordinator: SaveCustomRpcCoordinator) {
        enabledServersViewController.pushReloadServersIfNeeded()
        delegate?.restartToReloadServersQueued(in: self)
    }
}
