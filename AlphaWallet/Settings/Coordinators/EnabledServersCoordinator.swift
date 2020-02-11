// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol EnabledServersCoordinatorDelegate: class {
    func didSelectServers(servers: [RPCServer], in coordinator: EnabledServersCoordinator)
    func didSelectDismiss(in coordinator: EnabledServersCoordinator)
}

class EnabledServersCoordinator: Coordinator {
    static let serversOrdered: [RPCServer] = ServersCoordinator.serversOrdered

    private let serverChoices = EnabledServersCoordinator.serversOrdered
    private let navigationController: UINavigationController
    private let selectedServers: [RPCServer]

    private lazy var enabledServersViewController: EnabledServersViewController = {
        let controller = EnabledServersViewController()
        controller.configure(viewModel: EnabledServersViewModel(servers: serverChoices, selectedServers: selectedServers))
        controller.delegate = self
        controller.hidesBottomBarWhenPushed = true
        return controller
    }()

    var coordinators: [Coordinator] = []
    weak var delegate: EnabledServersCoordinatorDelegate?

    init(navigationController: UINavigationController, selectedServers: [RPCServer]) {
        self.navigationController = navigationController
        self.selectedServers = selectedServers
    }

    func start() {
        navigationController.pushViewController(enabledServersViewController, animated: true)
    }

    func stop() {
        navigationController.popViewController(animated: true)
    }
}

extension EnabledServersCoordinator: EnabledServersViewControllerDelegate {
    func didSelectServers(servers: [RPCServer], in viewController: EnabledServersViewController) {
        delegate?.didSelectServers(servers: servers, in: self)
    }

    func didDismiss(viewController: EnabledServersViewController) {
        delegate?.didSelectDismiss(in: self)
    }
}
