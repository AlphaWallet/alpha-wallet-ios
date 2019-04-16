// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol ServersCoordinatorDelegate: class {
    func didSelectServer(server: RPCServerOrAuto, in coordinator: ServersCoordinator)
    func didSelectDismiss(in coordinator: ServersCoordinator)
}

class ServersCoordinator: Coordinator {
    static let serversOrdered: [RPCServer] = [
        .main,
        .xDai,
        .classic,
        .poa,
        .ropsten,
        .goerli,
        .kovan,
        .rinkeby,
        .sokol,
    ]

    private let defaultServer: RPCServerOrAuto
    private let includeAny: Bool

    private var serverChoices: [RPCServerOrAuto] {
        let servers: [RPCServerOrAuto] = ServersCoordinator.serversOrdered.map { .server($0) }
        if includeAny {
            return [.auto] + servers
        } else {
            return servers
        }
    }

    var coordinators: [Coordinator] = []

    lazy var serversViewController: ServersViewController = {
        let controller = ServersViewController()
        controller.configure(viewModel: ServersViewModel(servers: serverChoices, selectedServer: defaultServer))
        controller.delegate = self
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .done, target: self, action: #selector(dismiss))
        return controller
    }()
    weak var delegate: ServersCoordinatorDelegate?

    init(defaultServer: RPCServerOrAuto) {
        self.defaultServer = defaultServer
        self.includeAny = true
    }

    init(defaultServer: RPCServer) {
        self.defaultServer = .server(defaultServer)
        self.includeAny = false
    }

    func start() {
    }

    @objc private func dismiss() {
        delegate?.didSelectDismiss(in: self)
    }
}

extension ServersCoordinator: ServersViewControllerDelegate {
    func didSelectServer(server: RPCServerOrAuto, in viewController: ServersViewController) {
        delegate?.didSelectServer(server: server, in: self)
    }
}

