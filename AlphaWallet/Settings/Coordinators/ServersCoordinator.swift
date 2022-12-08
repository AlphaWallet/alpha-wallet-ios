// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import PromiseKit
import AlphaWalletFoundation

protocol ServersCoordinatorDelegate: AnyObject {
    func didSelectServer(selection: ServerSelection, in coordinator: ServersCoordinator)
    func didClose(in coordinator: ServersCoordinator)
}

class ServersCoordinator: Coordinator {
    //Cannot be `let` as the chains can change dynamically without the app being restarted (i.e. killed). The UI can be restarted though (when switching changes)
    static var serversOrdered: [RPCServer] {
        return [
            .main,
            .xDai,
            .polygon,
            .classic,
            .poa,
            .goerli,
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
            .mumbai_testnet,
            .optimismGoerli,
            .arbitrumGoerli,
            .optimistic,
            .cronosMainnet,
            .cronosTestnet,
            .arbitrum,
            .klaytnCypress,
            .klaytnBaobabTestnet,
            //Need to update Covalent.NetworkProvider.isSupport() if we enable .ioTeX and/or .ioTeXTestnet
            //.ioTeX,
            //.ioTeXTestnet,
            .palm,
            .palmTestnet,
        ] + RPCServer.customServers
    }

    let viewModel: ServersViewModel
    lazy var serversViewController: ServersViewController = {
        let controller = ServersViewController(viewModel: viewModel)
        controller.delegate = self

        controller.hidesBottomBarWhenPushed = true

        return controller
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: ServersCoordinatorDelegate?

    init(defaultServer: RPCServerOrAuto, config: Config, navigationController: UINavigationController) {
        self.navigationController = navigationController
        let serverChoices = ServersCoordinator.serverChoices(includeAny: true, config: config)

        self.viewModel = ServersViewModel(servers: serverChoices, selectedServers: [defaultServer])
    }

    init(defaultServer: RPCServer, config: Config, navigationController: UINavigationController) {
        self.navigationController = navigationController
        let serverChoices = ServersCoordinator.serverChoices(includeAny: false, config: config)
        self.viewModel = ServersViewModel(servers: serverChoices, selectedServers: [.server(defaultServer)])
    }

    init(viewModel: ServersViewModel, navigationController: UINavigationController) {
        self.navigationController = navigationController
        self.viewModel = viewModel
    }

    static func serverChoices(includeAny: Bool, config: Config) -> [RPCServerOrAuto] {
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
}

extension ServersCoordinator: ServersViewControllerDelegate {

    func didSelectServer(selection: ServerSelection, in viewController: ServersViewController) {
        delegate?.didSelectServer(selection: selection, in: self)
    }

    func didClose(in viewController: ServersViewController) {
        delegate?.didClose(in: self)
    }
}
