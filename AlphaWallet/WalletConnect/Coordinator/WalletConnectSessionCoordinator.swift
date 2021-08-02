//
//  WalletConnectSessionCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.10.2020.
//

import Foundation
import UIKit

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

    init(analyticsCoordinator: AnalyticsCoordinator, navigationController: UINavigationController, server: WalletConnectServer, session: WalletConnectSession) {
        self.analyticsCoordinator = analyticsCoordinator
        self.navigationController = navigationController
        self.server = server
        self.session = session

        viewController = WalletConnectSessionViewController(viewModel: .init(server: server, session: session))
        viewController.delegate = self

        server.sessions.subscribe { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.viewController.reload()
        }
    }

    func start() {
        navigationController.pushViewController(viewController, animated: true)
    }
}

extension WalletConnectSessionCoordinator: WalletConnectSessionViewControllerDelegate {

    func didDismiss(in controller: WalletConnectSessionViewController) {
        guard let delegate = delegate else { return }
        navigationController.popViewController(animated: true)
        delegate.didDismiss(in: self)
    }

    func controller(_ controller: WalletConnectSessionViewController, disconnectSelected sender: UIButton) {
        guard let delegate = delegate else { return }

        analyticsCoordinator.log(action: Analytics.Action.walletConnectDisconnect)
        do {
            try server.disconnect(session: session)
        } catch {
            //no-op
        }
        navigationController.popViewController(animated: true)
        delegate.didDismiss(in: self)
    }
}
