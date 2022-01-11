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
    private let provider: WalletConnectServerProviderType
    private var viewController: WalletConnectSessionViewController
    private let session: AlphaWallet.WalletConnect.Session

    var coordinators: [Coordinator] = []
    weak var delegate: WalletConnectSessionCoordinatorDelegate?
    private let config = Config()
    
    init(analyticsCoordinator: AnalyticsCoordinator, navigationController: UINavigationController, provider: WalletConnectServerProviderType, session: AlphaWallet.WalletConnect.Session) {
        self.analyticsCoordinator = analyticsCoordinator
        self.navigationController = navigationController
        self.provider = provider
        self.session = session

        viewController = WalletConnectSessionViewController(viewModel: .init(provider: provider, session: session), provider: provider)
        viewController.delegate = self
        viewController.navigationItem.hidesBackButton = true
        viewController.navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(self, selector: #selector(backButtonSelected))
    }

    func start() {
        navigationController.pushViewController(viewController, animated: true)
    }

    @objc private func backButtonSelected(_ sender: UIBarButtonItem) {
        navigationController.popViewController(animated: true)
        delegate?.didDismiss(in: self)
    }
}

extension WalletConnectSessionCoordinator: WalletConnectSessionViewControllerDelegate {

    private var serverChoices: [RPCServer] {
        ServersCoordinator.serversOrdered.filter { config.enabledServers.contains($0) }
    }

    func controller(_ controller: WalletConnectSessionViewController, switchNetworkSelected sender: UIButton) {
        analyticsCoordinator.log(action: Analytics.Action.walletConnectSwitchNetwork)

        let selectedServers: [RPCServerOrAuto] = controller.rpcServers.map { return .server($0) }
        let servers = serverChoices.filter { config.enabledServers.contains($0) } .compactMap { RPCServerOrAuto.server($0) }
        var viewModel = ServersViewModel(servers: servers, selectedServers: selectedServers, displayWarningFooter: false)
        viewModel.multipleSessionSelectionEnabled = session.isMultipleServersEnabled

        firstly {
            ServersCoordinator.promise(navigationController, viewModel: viewModel, coordinator: self)
        }.done { selection in
            let servers = selection.asServersArray
            self.analyticsCoordinator.log(action: Analytics.Action.switchedServer, properties: [
                Analytics.Properties.source.rawValue: "walletConnect"
            ])
            try? self.provider.updateSession(session: self.session, servers: servers)
        }.catch { _ in
            self.analyticsCoordinator.log(action: Analytics.Action.cancelsSwitchServer, properties: [
                Analytics.Properties.source.rawValue: "walletConnect"
            ])
        }
    }

    func controller(_ controller: WalletConnectSessionViewController, disconnectSelected sender: UIButton) {
        analyticsCoordinator.log(action: Analytics.Action.walletConnectDisconnect)

        try? provider.disconnectSession(session: session)
        navigationController.popViewController(animated: true)
        delegate?.didDismiss(in: self)
    }
}
