// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import PromiseKit

protocol ServersCoordinatorDelegate: class {
    func didSelectServer(server: RPCServerOrAuto, in coordinator: ServersCoordinator)
    func didSelectDismiss(in coordinator: ServersCoordinator)
}

class ServersCoordinator: Coordinator {
    //Cannot be `let` as the chains can change dynamically without the app being restarted (i.e. killed). The UI can be restarted though (when switching changes)
    static var serversOrdered: [RPCServer] {
        [
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
            .callisto,
            .heco,
            .heco_testnet,
            .artis_sigma1,
            .artis_tau1,
            .fantom,
            .fantom_testnet,
            .avalanche,
            .avalanche_testnet,
            .polygon,
            .mumbai_testnet,
            .optimistic,
            .optimisticKovan,
        ] + RPCServer.servers
    }

    private let viewModel: ServersViewModel
    private lazy var serversViewController: ServersViewController = {
        let controller = ServersViewController(viewModel: viewModel)
        controller.delegate = self
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(self, selector: #selector(dismiss))
        controller.hidesBottomBarWhenPushed = true

        return controller
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: ServersCoordinatorDelegate?

    init(defaultServer: RPCServerOrAuto, config: Config, navigationController: UINavigationController) {
        self.navigationController = navigationController
        let serverChoices = ServersCoordinator.serverChoices(includeAny: true, config: config)

        self.viewModel = ServersViewModel(servers: serverChoices, selectedServer: defaultServer)
    }

    init(defaultServer: RPCServer, config: Config, navigationController: UINavigationController) {
        self.navigationController = navigationController
        let serverChoices = ServersCoordinator.serverChoices(includeAny: false, config: config)
        self.viewModel = ServersViewModel(servers: serverChoices, selectedServer: .server(defaultServer))
    }

    init(viewModel: ServersViewModel, navigationController: UINavigationController) {
        self.navigationController = navigationController
        self.viewModel = viewModel
    }

    private static func serverChoices(includeAny: Bool, config: Config) -> [RPCServerOrAuto] {
        let enabledServers = ServersCoordinator.serversOrdered.filter { config.enabledServers.contains($0) }
        let servers: [RPCServerOrAuto] = enabledServers.map { .server($0) }
        if includeAny {
            return [.auto] + servers
        } else {
            return servers
        }
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

private class ServersCoordinatorBridgeToPromise {

    private let navigationController: UINavigationController
    private let (promiseToReturn, seal) = Promise<RPCServer?>.pending()
    private var retainCycle: ServersCoordinatorBridgeToPromise?

    init(_ navigationController: UINavigationController, coordinator: Coordinator, viewModel: ServersViewModel) {
        self.navigationController = navigationController

        retainCycle = self

        let newCoordinator = ServersCoordinator(viewModel: viewModel, navigationController: navigationController)
        newCoordinator.delegate = self
        coordinator.addCoordinator(newCoordinator)

        promiseToReturn.ensure {
            // ensure we break the retain cycle
            coordinator.removeCoordinator(newCoordinator)
            self.retainCycle = nil
        }.cauterize()

        newCoordinator.start()
    }

    var promise: Promise<RPCServer?> {
        return promiseToReturn
    }
}

extension ServersCoordinatorBridgeToPromise: ServersCoordinatorDelegate {

    func didSelectServer(server: RPCServerOrAuto, in coordinator: ServersCoordinator) {
        navigationController.popViewController(animated: true) {
            switch server {
            case .server(let value):
                self.seal.fulfill(value)
            case .auto:
                //TODO pass in `Config `instance instead
                self.seal.fulfill(Config().anyEnabledServer())
            }
        }
    }

    func didSelectDismiss(in coordinator: ServersCoordinator) {
        navigationController.popViewController(animated: true) {
            self.seal.fulfill(.none)
        }
    }
}

extension ServersCoordinator {
    static func promise(_ navigationController: UINavigationController, viewModel: ServersViewModel, coordinator: Coordinator) -> Promise<RPCServer?> {
        let bridge = ServersCoordinatorBridgeToPromise(navigationController, coordinator: coordinator, viewModel: viewModel)
        return bridge.promise
    }
}
