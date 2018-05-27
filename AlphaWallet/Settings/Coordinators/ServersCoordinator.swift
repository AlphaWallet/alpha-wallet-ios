// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol ServersCoordinatorDelegate: class {
    func didSelectServer(server: RPCServer, in coordinator: ServersCoordinator)
}

class ServersCoordinator: Coordinator {
    var coordinators: [Coordinator] = []
    var config: Config

    lazy var serversViewController: ServersViewController = {
        let servers: [RPCServer] = {
            return [
                RPCServer.main,
                RPCServer.classic,
                RPCServer.poa,
                // RPCServer.callisto, TODO: Enable.
                RPCServer.kovan,
                RPCServer.ropsten,
                RPCServer.rinkeby,
                RPCServer.sokol,
            ]
        }()
        let controller = ServersViewController()
        controller.configure(viewModel: ServersViewModel(servers: servers, selectedServer: config.server))
        controller.delegate = self
        return controller
    }()
    weak var delegate: ServersCoordinatorDelegate?

    init(config: Config) {
        self.config = config
    }

    func start() {
    }
}

extension ServersCoordinator: ServersViewControllerDelegate {
    func didSelectServer(server: RPCServer, in viewController: ServersViewController) {
        config.chainID = server.chainID
        delegate?.didSelectServer(server: server, in: self)
    }
}

