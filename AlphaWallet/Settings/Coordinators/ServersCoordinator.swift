// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol ServersCoordinatorDelegate: AnyObject {
    func didSelectServer(selection: ServerSelection, in coordinator: ServersCoordinator)
    func didClose(in coordinator: ServersCoordinator)
}

class ServersCoordinator: Coordinator {
    //Cannot be `let` as the chains can change dynamically without the app being restarted (i.e. killed). The UI can be restarted though (when switching changes)
    static var serversOrdered: [RPCServer] {
        return RPCServer.availableServers.sorted()
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

    init(defaultServer: RPCServerOrAuto,
         serversProvider: ServersProvidable,
         navigationController: UINavigationController) {

        self.navigationController = navigationController
        let serverChoices = ServersCoordinator.serverChoices(includeAny: true, serversProvider: serversProvider)

        self.viewModel = ServersViewModel(servers: serverChoices, selectedServers: [defaultServer])
    }

    init(defaultServer: RPCServer,
         serversProvider: ServersProvidable,
         navigationController: UINavigationController) {

        self.navigationController = navigationController
        let serverChoices = ServersCoordinator.serverChoices(includeAny: false, serversProvider: serversProvider)
        self.viewModel = ServersViewModel(servers: serverChoices, selectedServers: [.server(defaultServer)])
    }

    init(viewModel: ServersViewModel,
         navigationController: UINavigationController) {
        
        self.navigationController = navigationController
        self.viewModel = viewModel
    }

    static func serverChoices(includeAny: Bool, serversProvider: ServersProvidable) -> [RPCServerOrAuto] {
        let enabledServers = ServersCoordinator.serversOrdered.filter { serversProvider.enabledServers.contains($0) }
        let servers: [RPCServerOrAuto] = enabledServers.map { .server($0) }
        if includeAny {
            return [.auto] + servers
        } else {
            return servers
        }
    }

    func start(animated: Bool = true) {
        navigationController.pushViewController(serversViewController, animated: animated)
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
