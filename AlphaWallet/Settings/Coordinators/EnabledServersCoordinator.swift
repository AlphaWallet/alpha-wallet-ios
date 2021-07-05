// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol EnabledServersCoordinatorDelegate: class {
    func didSelectServers(servers: [RPCServer], in coordinator: EnabledServersCoordinator)
    func didSelectDismiss(in coordinator: EnabledServersCoordinator)
    func restartToAddEnableAndSwitchBrowserToServer(in coordinator: EnabledServersCoordinator)
    func restartToRemoveServer(in coordinator: EnabledServersCoordinator)
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

    func stop() {
        navigationController.popViewController(animated: true)
    }

    @objc private func addRPCSelected() {
        let coordinator = AddRPCServerCoordinator(navigationController: navigationController, config: Config(), restartQueue: restartQueue, analyticsCoordinator: analyticsCoordinator)
        coordinator.delegate = self
        addCoordinator(coordinator)

        coordinator.start()
    }
}

extension EnabledServersCoordinator: EnabledServersViewControllerDelegate {
    func didSelectServers(servers: [RPCServer], in viewController: EnabledServersViewController) {
        delegate?.didSelectServers(servers: servers, in: self)
    }

    func didDismiss(viewController: EnabledServersViewController) {
        delegate?.didSelectDismiss(in: self)
    }

    func notifyRemoveCustomChainQueued(in viewController: EnabledServersViewController) {
        delegate?.restartToRemoveServer(in: self)
    }
}

extension EnabledServersCoordinator: AddRPCServerCoordinatorDelegate {
    func didDismiss(in coordinator: AddRPCServerCoordinator) {
        removeCoordinator(coordinator)
    }

    func restartToAddEnableAndSwitchBrowserToServer(in coordinator: AddRPCServerCoordinator) {
        delegate?.restartToAddEnableAndSwitchBrowserToServer(in: self)
    }
}