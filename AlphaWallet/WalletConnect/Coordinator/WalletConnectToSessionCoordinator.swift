//
//  WalletConnectToSessionCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.02.2021.
//

import UIKit
import PromiseKit

protocol WalletConnectToSessionCoordinatorDelegate: AnyObject {
    func coordinator(_ coordinator: WalletConnectToSessionCoordinator, didCompleteWithConnection result: WalletConnectServer.ConnectionChoice)
}

class WalletConnectToSessionCoordinator: Coordinator {
    var coordinators: [Coordinator] = []

    private let analyticsCoordinator: AnalyticsCoordinator
    private let connection: WalletConnectConnection
    private let presentationNavigationController: UINavigationController
    private lazy var viewModel = WalletConnectToSessionViewModel(connection: connection, serverToConnect: serverToConnect)
    private lazy var viewController: WalletConnectToSessionViewController = {
        let viewController = WalletConnectToSessionViewController(viewModel: viewModel)
        viewController.delegate = self

        return viewController
    }()
    private lazy var navigationController: UINavigationController = {
        let controller = UINavigationController(rootViewController: viewController)
        controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = .crossDissolve
        controller.view.backgroundColor = UIColor.black.withAlphaComponent(0.6)

        return controller
    }()
    private var serverToConnect: RPCServer
    private let serverChoices: [RPCServer]
    private let config: Config
    weak var delegate: WalletConnectToSessionCoordinatorDelegate?

    init(analyticsCoordinator: AnalyticsCoordinator, connection: WalletConnectConnection, navigationController: UINavigationController, serverChoices: [RPCServer], config: Config) {
        self.config = config
        self.analyticsCoordinator = analyticsCoordinator
        self.connection = connection
        self.serverToConnect = connection.server ?? .main
        self.presentationNavigationController = navigationController
        self.serverChoices = serverChoices
    }

    func start() {
        guard let keyWindow = UIApplication.shared.firstKeyWindow else { return }
        analyticsCoordinator.log(navigation: Analytics.Navigation.walletConnect)

        if let controller = keyWindow.rootViewController?.presentedViewController {
            controller.present(navigationController, animated: false)
        } else {
            presentationNavigationController.present(navigationController, animated: false)
        }

        viewController.configure(for: viewModel)
        viewController.reloadView()
    }

    private func dismiss(animated: Bool = true, completion: @escaping () -> Void) {
        viewController.dismissViewAnimated {
            self.navigationController.dismiss(animated: animated, completion: completion)
        }
    }
}

extension WalletConnectToSessionCoordinator: WalletConnectToSessionViewControllerDelegate {

    func changeConnectionServerSelected(in controller: WalletConnectToSessionViewController) {
        analyticsCoordinator.log(navigation: Analytics.Navigation.switchServers, properties: [Analytics.Properties.source.rawValue: "walletConnect"])

        let servers = serverChoices.filter { config.enabledServers.contains($0) } .compactMap { RPCServerOrAuto.server($0) }
        let viewModel = ServersViewModel(servers: servers, selectedServer: .server(serverToConnect), displayWarningFooter: false)

        firstly {
            ServersCoordinator.promise(navigationController, viewModel: viewModel, coordinator: self)
        }.done { server in
            if let server = server {
                self.analyticsCoordinator.log(action: Analytics.Action.switchedServer, properties: [Analytics.Properties.source.rawValue: "walletConnect"])
                self.serverToConnect = server
                self.viewModel.set(serverToConnect: server)

                self.viewController.configure(for: self.viewModel)
                self.viewController.reloadView()
            } else {
                self.analyticsCoordinator.log(action: Analytics.Action.cancelsSwitchServer, properties: [Analytics.Properties.source.rawValue: "walletConnect"])
            }
        }.cauterize()
    }

    func controller(_ controller: WalletConnectToSessionViewController, continueButtonTapped sender: UIButton) {
        if config.enabledServers.contains(serverToConnect) {
            analyticsCoordinator.log(action: Analytics.Action.walletConnectConnect, properties: [Analytics.Properties.chain.rawValue: serverToConnect.chainID])
            dismiss(animated: true, completion: {
                guard let delegate = self.delegate else { return }

                delegate.coordinator(self, didCompleteWithConnection: .connect(self.serverToConnect))
            })
        } else {
            analyticsCoordinator.log(action: Analytics.Action.walletConnectConnectionFailed, properties: [Analytics.Properties.chain.rawValue: serverToConnect.chainID, Analytics.Properties.reason.rawValue: "Chain Disabled"])
            let coordinator = ServerUnavailableCoordinator(navigationController: navigationController, server: serverToConnect, coordinator: self)
            coordinator.start().done { _ in
                //no-op
            }.cauterize()
        }
    }

    func didClose(in controller: WalletConnectToSessionViewController) {
        analyticsCoordinator.log(action: Analytics.Action.walletConnectCancel)
        dismiss(animated: true, completion: {
            guard let delegate = self.delegate else { return }

            delegate.coordinator(self, didCompleteWithConnection: .cancel)
        })
    }
}
