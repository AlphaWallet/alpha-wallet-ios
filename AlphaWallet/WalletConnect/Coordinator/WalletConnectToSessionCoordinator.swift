//
//  WalletConnectToSessionCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.02.2021.
//

import UIKit
import PromiseKit

protocol WalletConnectToSessionCoordinatorDelegate: AnyObject {
    func coordinator(_ coordinator: WalletConnectToSessionCoordinator, didCompleteWithConnection result: AlphaWallet.WalletConnect.SessionProposalResponse)
}

class WalletConnectToSessionCoordinator: Coordinator {
    var coordinators: [Coordinator] = []

    private let analyticsCoordinator: AnalyticsCoordinator
    private let sessionProposal: AlphaWallet.WalletConnect.SessionProposal
    private let presentationNavigationController: UINavigationController
    private lazy var viewModel = WalletConnectToSessionViewModel(sessionProposal: sessionProposal, serversToConnect: serversToConnect)
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
    private var serversToConnect: [RPCServer]
    private let serverChoices: [RPCServer]
    private let config: Config
    weak var delegate: WalletConnectToSessionCoordinatorDelegate?

    init(analyticsCoordinator: AnalyticsCoordinator, sessionProposal: AlphaWallet.WalletConnect.SessionProposal, navigationController: UINavigationController, serverChoices: [RPCServer], config: Config) {
        self.config = config
        self.analyticsCoordinator = analyticsCoordinator
        self.sessionProposal = sessionProposal
        self.serversToConnect = sessionProposal.servers
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
        analyticsCoordinator.log(navigation: Analytics.Navigation.switchServers, properties: [
            Analytics.Properties.source.rawValue: "walletConnect"
        ])

        let servers = serverChoices.filter { config.enabledServers.contains($0) } .compactMap { RPCServerOrAuto.server($0) }
        let serversToConnect: [RPCServerOrAuto] = serversToConnect.map { .server($0) }
        //NOTE: multiple server selection is disable for this case
        let viewModel = ServersViewModel(servers: servers, selectedServers: serversToConnect, displayWarningFooter: false)

        firstly {
            ServersCoordinator.promise(navigationController, viewModel: viewModel, coordinator: self)
        }.done { selection in
            self.analyticsCoordinator.log(action: Analytics.Action.switchedServer, properties: [
                Analytics.Properties.source.rawValue: "walletConnect"
            ])

            self.serversToConnect = selection.asServersArray
            self.viewModel.set(serversToConnect: self.serversToConnect)
            self.viewController.configure(for: self.viewModel)
            self.viewController.reloadView()
        }.catch { _ in
            self.analyticsCoordinator.log(action: Analytics.Action.cancelsSwitchServer, properties: [
                Analytics.Properties.source.rawValue: "walletConnect"
            ])
        }
    }

    private func validateEnabledServers(serversToConnect: [RPCServer]) throws {
        struct MissingRPCServer: Error {}
        let missedServers = serversToConnect.filter { !config.enabledServers.contains($0) }
        if missedServers.isEmpty {
            //no-op
        } else {
            throw MissingRPCServer()
        }
    }

    func controller(_ controller: WalletConnectToSessionViewController, continueButtonTapped sender: UIButton) {
        do {
            try validateEnabledServers(serversToConnect: serversToConnect)

            analyticsCoordinator.log(action: Analytics.Action.walletConnectConnect, properties: [
                Analytics.Properties.chains.rawValue: serversToConnect.map({ $0.chainID })
            ])

            dismiss(animated: true, completion: {
                //NOTE: all the time we should have at least 1 server to connect
                guard let server = self.serversToConnect.first else { return }
                self.delegate?.coordinator(self, didCompleteWithConnection: .connect(server))
            })
        } catch {
            analyticsCoordinator.log(action: Analytics.Action.walletConnectConnectionFailed, properties: [
                Analytics.Properties.chains.rawValue: serversToConnect.map({ $0.chainID }),
                Analytics.Properties.reason.rawValue: "Chain Disabled"
            ])

            let coordinator = ServerUnavailableCoordinator(navigationController: navigationController, servers: serversToConnect, coordinator: self)
            coordinator.start().done { _ in
                //no-op
            }.cauterize()
        }
    }

    func didClose(in controller: WalletConnectToSessionViewController) {
        analyticsCoordinator.log(action: Analytics.Action.walletConnectCancel)
        dismiss(animated: true, completion: {
            self.delegate?.coordinator(self, didCompleteWithConnection: .cancel)
        })
    }
}
