//
//  WalletConnectSessionCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.10.2020.
//

import Foundation
import UIKit
import PromiseKit

protocol WalletConnectSessionCoordinatorDelegate: AnyObject {
    func didDismiss(in coordinator: WalletConnectSessionCoordinator)
}

class WalletConnectSessionCoordinator: Coordinator {
    private let analyticsCoordinator: AnalyticsCoordinator
    private let navigationController: UINavigationController
    private let server: WalletConnectServer
    private var viewController: WalletConnectSessionViewController
    private let session: WalletConnectSession

    var coordinators: [Coordinator] = []
    weak var delegate: WalletConnectSessionCoordinatorDelegate?
    private let config = Config()
    
    init(analyticsCoordinator: AnalyticsCoordinator, navigationController: UINavigationController, server: WalletConnectServer, session: WalletConnectSession) {
        self.analyticsCoordinator = analyticsCoordinator
        self.navigationController = navigationController
        self.server = server
        self.session = session

        viewController = WalletConnectSessionViewController(viewModel: .init(server: server, session: session))
        viewController.delegate = self

        server.sessions.subscribe { [weak self] _ in
            self?.viewController.reload()
        }
    }

    func start() {
        navigationController.pushViewController(viewController, animated: true)
    }
}

extension WalletConnectSessionCoordinator: WalletConnectSessionViewControllerDelegate {

    func didDismiss(in controller: WalletConnectSessionViewController) {
        navigationController.popViewController(animated: true)
        delegate?.didDismiss(in: self)
    }

    private var serverChoices: [RPCServer] {
        ServersCoordinator.serversOrdered.filter { config.enabledServers.contains($0) }
    }

    func controller(_ controller: WalletConnectSessionViewController, switchNetworkSelected sender: UIButton) {
        analyticsCoordinator.log(action: Analytics.Action.walletConnectSwitchNetwork)

        let rpcServer = controller.rpcServer ?? .main
        let servers = serverChoices.filter { config.enabledServers.contains($0) } .compactMap { RPCServerOrAuto.server($0) }
        let viewModel = ServersViewModel(servers: servers, selectedServer: .server(rpcServer), displayWarningFooter: false)

        firstly {
            ServersCoordinator.promise(navigationController, viewModel: viewModel, coordinator: self)
        }.done { server in
            if let server = server {
                self.analyticsCoordinator.log(action: Analytics.Action.switchedServer, properties: [Analytics.Properties.source.rawValue: "walletConnect"])

                try? self.server.updateSession(session: self.session, server: server)
            } else {
                self.analyticsCoordinator.log(action: Analytics.Action.cancelsSwitchServer, properties: [Analytics.Properties.source.rawValue: "walletConnect"])
            }
        }.cauterize()
    }

    func controller(_ controller: WalletConnectSessionViewController, disconnectSelected sender: UIButton) {
        analyticsCoordinator.log(action: Analytics.Action.walletConnectDisconnect)

        try? server.disconnect(session: session)
        navigationController.popViewController(animated: true)
        delegate?.didDismiss(in: self)
    }
}
