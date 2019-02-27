// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol EnabledServersCoordinatorDelegate: class {
    func didSelectServers(servers: [RPCServer], in coordinator: EnabledServersCoordinator)
    func didSelectDismiss(in coordinator: EnabledServersCoordinator)
}

class EnabledServersCoordinator: Coordinator {
    static let serversOrdered: [RPCServer] = ServersCoordinator.serversOrdered

    private let serverChoices = EnabledServersCoordinator.serversOrdered
    private let selectedServers: [RPCServer]

    var coordinators: [Coordinator] = []

    lazy var enabledServersViewController: EnabledServersViewController = {
        let controller = EnabledServersViewController()
        controller.configure(viewModel: EnabledServersViewModel(servers: serverChoices, selectedServers: selectedServers))
        controller.delegate = self
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .done, target: self, action: #selector(dismiss))
        controller.hidesBottomBarWhenPushed = true
        return controller
    }()
    weak var delegate: EnabledServersCoordinatorDelegate?

    init(selectedServers: [RPCServer]) {
        self.selectedServers = selectedServers
    }

    func start() {
    }

    @objc private func dismiss() {
        delegate?.didSelectDismiss(in: self)
    }
}

extension EnabledServersCoordinator: EnabledServersViewControllerDelegate {
    func didSelectServers(servers: [RPCServer], in viewController: EnabledServersViewController) {
        delegate?.didSelectServers(servers: servers, in: self)
    }
}

