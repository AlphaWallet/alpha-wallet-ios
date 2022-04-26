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
    private let navigationController: UINavigationController
    private lazy var viewModel = WalletConnectToSessionViewModel(sessionProposal: sessionProposal, serversToConnect: serversToConnect)
    private lazy var rootViewController: WalletConnectToSessionViewController = {
        let viewController = WalletConnectToSessionViewController(viewModel: viewModel)
        viewController.delegate = self

        return viewController
    }()
    private weak var serversViewController: UIViewController?
    private lazy var hostViewController: FloatingPanelController = {
        let panel = FloatingPanelController(isPanEnabled: false)
        panel.layout = SelfSizingPanelLayout(referenceGuide: .superview)
        panel.shouldDismissOnBackdrop = true
        panel.delegate = self
        panel.set(contentViewController: rootViewController)

        return panel
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
        self.navigationController = navigationController
        self.serverChoices = serverChoices
    }

    func start() {
        analyticsCoordinator.log(navigation: Analytics.Navigation.walletConnect)

        let presenter = UIApplication.shared.presentedViewController(or: navigationController)
        presenter.present(hostViewController, animated: true)

        rootViewController.configure(for: viewModel)
        rootViewController.reloadView()
    }

    func close(completion: @escaping () -> Void) {
        navigationController.dismiss(animated: true, completion: completion)
    }
}

extension WalletConnectToSessionCoordinator: FloatingPanelControllerDelegate {
    func floatingPanelDidRemove(_ fpc: FloatingPanelController) {
        delegate?.coordinator(self, didCompleteWithConnection: .cancel)
    }
}

extension WalletConnectToSessionCoordinator: ServersCoordinatorDelegate {

    func didSelectServer(selection: ServerSelection, in coordinator: ServersCoordinator) {
        removeCoordinator(coordinator)
        serversViewController?.navigationController?.dismiss(animated: true)
        analyticsCoordinator.log(action: Analytics.Action.switchedServer, properties: [
            Analytics.Properties.source.rawValue: "walletConnect"
        ])

        serversToConnect = selection.asServersArray
        viewModel.set(serversToConnect: serversToConnect)
        rootViewController.configure(for: viewModel)
        rootViewController.reloadView()
    }

    func didSelectDismiss(in coordinator: ServersCoordinator) {
        removeCoordinator(coordinator)
        serversViewController?.navigationController?.dismiss(animated: true)
        analyticsCoordinator.log(action: Analytics.Action.cancelsSwitchServer, properties: [
            Analytics.Properties.source.rawValue: "walletConnect"
        ])
    }
}

extension WalletConnectToSessionCoordinator: WalletConnectToSessionViewControllerDelegate {

    func didInvalidateLayout(in controller: WalletConnectToSessionViewController) {
        hostViewController.invalidateLayout()
    }

    func changeConnectionServerSelected(in controller: WalletConnectToSessionViewController) {
        analyticsCoordinator.log(navigation: Analytics.Navigation.switchServers, properties: [
            Analytics.Properties.source.rawValue: "walletConnect"
        ])

        let servers = serverChoices.filter { config.enabledServers.contains($0) } .compactMap { RPCServerOrAuto.server($0) }
        let serversToConnect: [RPCServerOrAuto] = serversToConnect.map { .server($0) }
        //NOTE: multiple server selection is disable for this case
        let viewModel = ServersViewModel(servers: servers, selectedServers: serversToConnect, displayWarningFooter: false)

        let coordinator = ServersCoordinator(viewModel: viewModel, navigationController: navigationController)
        addCoordinator(coordinator)
        coordinator.delegate = self

        let navigationController = UINavigationController(rootViewController: coordinator.serversViewController)
        navigationController.makePresentationFullScreenForiOS13Migration()
        controller.navigationItem.leftBarButtonItem = .closeBarButton(self, selector: #selector(configureTransactionDidDismiss))

        self.serversViewController = coordinator.serversViewController

        hostViewController.present(navigationController, animated: true)
    }

    @objc func configureTransactionDidDismiss() {
        serversViewController?.navigationController?.dismiss(animated: true)
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

            close(completion: {
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
        close(completion: {
            self.delegate?.coordinator(self, didCompleteWithConnection: .cancel)
        })
    }
}
