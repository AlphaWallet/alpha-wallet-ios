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
        .binance_smart_chain,
        .binance_smart_chain_testnet,
        .heco,
        .heco_testnet,
        .artis_sigma1,
        .artis_tau1,
    ]

    private let defaultServer: RPCServerOrAuto
    private let includeAny: Bool
    private let config: Config

    private var serverChoices: [RPCServerOrAuto] {
        let enabledServers = ServersCoordinator.serversOrdered.filter { config.enabledServers.contains($0) }
        let servers: [RPCServerOrAuto] = enabledServers.map { .server($0) }
        if includeAny {
            return [.auto] + servers
        } else {
            return servers
        }
    }
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    lazy var serversViewController: ServersViewController = {
        let controller = ServersViewController()
        controller.configure(viewModel: ServersViewModel(servers: serverChoices, selectedServer: defaultServer))
        controller.delegate = self
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(self, selector: #selector(dismiss))
        controller.hidesBottomBarWhenPushed = true
        return controller
    }()
    weak var delegate: ServersCoordinatorDelegate?

    init(defaultServer: RPCServerOrAuto, config: Config, navigationController: UINavigationController) {
        self.defaultServer = defaultServer
        self.includeAny = true
        self.config = config
        self.navigationController = navigationController
    }

    init(defaultServer: RPCServer, config: Config, navigationController: UINavigationController) {
        self.defaultServer = .server(defaultServer)
        self.includeAny = false
        self.config = config
        self.navigationController = navigationController
    }

    func start() {
        navigationController.pushViewController(serversViewController, animated: true)
    }

    @objc private func dismiss() {
        delegate?.didSelectDismiss(in: self)
    }
}

extension ServersCoordinator: ServersViewControllerDelegate {
    func didSelectServer(server: RPCServerOrAuto, in viewController: ServersViewController) {
        delegate?.didSelectServer(server: server, in: self)
    }

    func didClose(in viewController: ServersViewController) {
        delegate?.didSelectDismiss(in: self)
    }
}

