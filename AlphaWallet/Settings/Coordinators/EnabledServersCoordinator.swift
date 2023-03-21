// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation
import Combine

protocol EnabledServersCoordinatorDelegate: AnyObject {
    func didClose(in coordinator: EnabledServersCoordinator)
}

class EnabledServersCoordinator: Coordinator {
    //Cannot be `let` as the chains can change dynamically without the app being restarted (i.e. killed). The UI can be restarted though (when switching changes)
    static var serversOrdered: [RPCServer] {
        ServersCoordinator.serversOrdered
    }

    let navigationController: UINavigationController

    private let selectedServers: [RPCServer]
    private let restartHandler: RestartQueueHandler
    private let analytics: AnalyticsLogger
    private let config: Config
    private let networkService: NetworkService
    private let serversProvider: ServersProvidable

    private (set) lazy var viewModel: EnabledServersViewModel = {
        return EnabledServersViewModel(
            selectedServers: selectedServers,
            restartHandler: restartHandler,
            serversProvider: serversProvider)
    }()

    private (set) lazy var enabledServersViewController: EnabledServersViewController = {
        let controller = EnabledServersViewController(viewModel: viewModel)
        controller.delegate = self
        controller.hidesBottomBarWhenPushed = true
        controller.navigationItem.rightBarButtonItem = .addBarButton(self, selector: #selector(addRpcServerSelected))

        return controller
    }()

    var coordinators: [Coordinator] = []
    weak var delegate: EnabledServersCoordinatorDelegate?

    init(navigationController: UINavigationController,
         selectedServers: [RPCServer],
         restartHandler: RestartQueueHandler,
         analytics: AnalyticsLogger,
         config: Config,
         networkService: NetworkService,
         serversProvider: ServersProvidable) {

        self.serversProvider = serversProvider
        self.networkService = networkService
        self.navigationController = navigationController
        self.selectedServers = selectedServers
        self.restartHandler = restartHandler
        self.analytics = analytics
        self.config = config
    }

    func start(animated: Bool = true) {
        enabledServersViewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(enabledServersViewController, animated: animated)
    }

    @objc private func addRpcServerSelected(_ sender: UIBarButtonItem) {
        let coordinator = SaveCustomRpcCoordinator(
            navigationController: navigationController,
            config: config,
            restartHandler: restartHandler,
            analytics: analytics,
            operation: .add,
            networkService: networkService)
        addCoordinator(coordinator)
        coordinator.delegate = self

        coordinator.start()
    }
}

extension EnabledServersCoordinator: EnabledServersViewControllerDelegate {

    func didClose(in viewController: EnabledServersViewController) {
        delegate?.didClose(in: self)
    }

    func didEditSelectedServer(customRpc: CustomRPC, in viewController: EnabledServersViewController) {
        let coordinator = SaveCustomRpcCoordinator(
            navigationController: navigationController,
            config: config,
            restartHandler: restartHandler,
            analytics: analytics,
            operation: .edit(customRpc),
            networkService: networkService)

        addCoordinator(coordinator)
        coordinator.delegate = self

        coordinator.start()
    }
}

extension EnabledServersCoordinator: SaveCustomRpcCoordinatorDelegate {
    func didDismiss(in coordinator: SaveCustomRpcCoordinator) {
        removeCoordinator(coordinator)
    }
}
