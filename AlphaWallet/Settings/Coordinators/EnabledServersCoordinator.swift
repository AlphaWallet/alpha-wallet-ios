// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

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
    private let analyticsCoordinator: AnalyticsCoordinator

    private lazy var enabledServersViewController: EnabledServersViewController = {
        let viewModel = EnabledServersViewModel(servers: serverChoices, selectedServers: selectedServers, mode: selectedServers.contains(where: { $0.isTestnet }) ? .testnet : .mainnet )
        let controller = EnabledServersViewController(viewModel: viewModel, restartQueue: restartQueue)
        controller.delegate = self
        controller.hidesBottomBarWhenPushed = true
        controller.navigationItem.rightBarButtonItem = .addBarButton(self, selector: #selector(addRPCSelected))

        return controller
    }()

    var coordinators: [Coordinator] = []
    weak var delegate: EnabledServersCoordinatorDelegate?

    init(navigationController: UINavigationController, selectedServers: [RPCServer], restartQueue: RestartTaskQueue, analyticsCoordinator: AnalyticsCoordinator) {
        self.navigationController = navigationController
        self.selectedServers = selectedServers
        self.restartQueue = restartQueue
        self.analyticsCoordinator = analyticsCoordinator
    }

    func start() {
        enabledServersViewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(enabledServersViewController, animated: true)
    }

    @objc private func addRPCSelected() {
        let coordinator = AddRPCServerCoordinator(navigationController: navigationController, config: Config(), restartQueue: restartQueue, analyticsCoordinator: analyticsCoordinator)
        coordinator.delegate = self
        addCoordinator(coordinator)

        coordinator.start()
    }
    
    private func edit(customRpc: CustomRPC, in viewController: EnabledServersViewController) {
        let coordinator = EditCustomRpcCoordinator(navigationController: navigationController, config: Config(), restartQueue: restartQueue, analyticsCoordinator: analyticsCoordinator, customRpc: customRpc)
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

extension EnabledServersCoordinator: AddRPCServerCoordinatorDelegate {
    func didDismiss(in coordinator: AddRPCServerCoordinator) {
        removeCoordinator(coordinator)
    }

    func restartToAddEnableAndSwitchBrowserToServer(in coordinator: AddRPCServerCoordinator) {
        enabledServersViewController.pushReloadServersIfNeeded()
        delegate?.restartToReloadServersQueued(in: self)
    }
}

extension EnabledServersCoordinator: EditCustomRpcCoordinatorDelegate {
    func didDismiss(in coordinator: EditCustomRpcCoordinator) {
        removeCoordinator(coordinator)
    }

    func restartToEdit(in coordinator: EditCustomRpcCoordinator) {
        enabledServersViewController.pushReloadServersIfNeeded()
        delegate?.restartToReloadServersQueued(in: self)
    }
}
