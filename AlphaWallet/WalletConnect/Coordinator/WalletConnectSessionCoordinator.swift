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
        let viewController = WalletConnectSessionViewController(viewModel: .init(provider: provider, session: session), provider: provider)
        viewController.delegate = self

        return viewController
    }()
    private let session: AlphaWallet.WalletConnect.Session

    var coordinators: [Coordinator] = []
    weak var delegate: WalletConnectSessionCoordinatorDelegate?
    private let config = Config()
    
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

    private var serverChoices: [RPCServer] {
        ServersCoordinator.serversOrdered.filter { config.enabledServers.contains($0) }
    }

    func controller(_ controller: WalletConnectSessionViewController, switchNetworkSelected sender: UIButton) {
        analytics.log(action: Analytics.Action.walletConnectSwitchNetwork)

        let selectedServers: [RPCServerOrAuto] = controller.rpcServers.map { return .server($0) }
        let servers = serverChoices.filter { config.enabledServers.contains($0) } .compactMap { RPCServerOrAuto.server($0) }
        var viewModel = ServersViewModel(servers: servers, selectedServers: selectedServers, displayWarningFooter: false)
        viewModel.multipleSessionSelectionEnabled = session.multipleServersSelection == .enabled

        firstly {
            ServersCoordinator.promise(navigationController, viewModel: viewModel, coordinator: self)
        }.done { selection in
            let servers = selection.asServersArray
            self.analytics.log(action: Analytics.Action.switchedServer, properties: [
                Analytics.Properties.source.rawValue: "walletConnect"
            ])
            try? self.provider.update(self.session.topicOrUrl, servers: servers)
        }.catch { _ in
            self.analytics.log(action: Analytics.Action.cancelsSwitchServer, properties: [
                Analytics.Properties.source.rawValue: "walletConnect"
            ])
        }
    }

    func controller(_ controller: WalletConnectSessionViewController, disconnectSelected sender: UIButton) {
        analytics.log(action: Analytics.Action.walletConnectDisconnect)

        try? provider.disconnect(session.topicOrUrl)
        navigationController.popViewController(animated: true)
        delegate?.didClose(in: self)
    }
}
