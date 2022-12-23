//
//  WalletConnectSessionCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.10.2020.
//

import Foundation
import UIKit
import PromiseKit
import AlphaWalletFoundation

protocol WalletConnectSessionCoordinatorDelegate: AnyObject {
    func didClose(in coordinator: WalletConnectSessionCoordinator)
}

class WalletConnectSessionCoordinator: Coordinator {
    private let analytics: AnalyticsLogger
    private let navigationController: UINavigationController
    private let provider: WalletConnectServerProviderType
    private lazy var viewController: WalletConnectSessionViewController = {
        let viewController = WalletConnectSessionViewController(viewModel: .init(provider: provider, session: session, analytics: analytics))
        viewController.delegate = self

        return viewController
    }()
    private let session: AlphaWallet.WalletConnect.Session
    
    var coordinators: [Coordinator] = []
    weak var delegate: WalletConnectSessionCoordinatorDelegate?

    init(analytics: AnalyticsLogger, navigationController: UINavigationController, provider: WalletConnectServerProviderType, session: AlphaWallet.WalletConnect.Session) {
        self.analytics = analytics
        self.navigationController = navigationController
        self.provider = provider
        self.session = session
    }

    func start() {
        navigationController.pushViewController(viewController, animated: true)
    }
}

extension WalletConnectSessionCoordinator: WalletConnectSessionViewControllerDelegate {

    func didClose(in controller: WalletConnectSessionViewController) {
        delegate?.didClose(in: self)
    }

    func controller(_ controller: WalletConnectSessionViewController, switchNetworkSelected sender: UIButton) {
        analytics.log(action: Analytics.Action.walletConnectSwitchNetwork)

        let coordinator = ServersCoordinator(viewModel: controller.viewModel.serversViewModel, navigationController: navigationController)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }
}

extension WalletConnectSessionCoordinator: ServersCoordinatorDelegate {

    func didSelectServer(selection: ServerSelection, in coordinator: ServersCoordinator) {
        let servers = selection.asServersArray
        analytics.log(action: Analytics.Action.switchedServer, properties: [
            Analytics.Properties.source.rawValue: "walletConnect"
        ])
        try? provider.update(session.topicOrUrl, servers: servers)
    }

    func didClose(in coordinator: ServersCoordinator) {
        removeCoordinator(coordinator)
        analytics.log(action: Analytics.Action.cancelsSwitchServer, properties: [
            Analytics.Properties.source.rawValue: "walletConnect"
        ])
    }
}
