//
//  WalletConnectSessionCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.10.2020.
//

import Foundation
import UIKit

protocol WalletConnectSessionCoordinatorDelegate: class {
    func didDismiss(in coordinator: WalletConnectSessionCoordinator)
}

class WalletConnectSessionCoordinator: Coordinator {

    private let navigationController: UINavigationController
    private let server: WalletConnectServer
    private var viewController: WalletConnectSessionViewController
    private let session: WalletConnectSession
    private var sessionsSubscribableKey: Subscribable<[WalletConnectSession]>.SubscribableKey?

    var coordinators: [Coordinator] = []
    weak var delegate: WalletConnectSessionCoordinatorDelegate?

    init(navigationController: UINavigationController, server: WalletConnectServer, session: WalletConnectSession) {
        self.navigationController = navigationController
        self.server = server
        self.session = session

        viewController = WalletConnectSessionViewController(viewModel: .init(server: server, session: session))
        viewController.delegate = self

        sessionsSubscribableKey = server.sessions.subscribe { [weak self] sessions in
            guard let strongSelf = self else { return }

            strongSelf.viewController.reload()
        }
    }

    func start() {
        navigationController.pushViewController(viewController, animated: true)
    }
}

extension WalletConnectSessionCoordinator: WalletConnectSessionViewControllerDelegate {

    func didDissmiss(in controller: WalletConnectSessionViewController) {
        guard let delegate = delegate else { return }

        navigationController.popViewController(animated: true)
        delegate.didDismiss(in: self)
    }

    func controller(_ controller: WalletConnectSessionViewController, dissconnectSelected sender: UIButton) {
        guard let delegate = delegate else { return }

        do {
            try server.disconnect(session: session)
        } catch {
            print(error)
        }

        navigationController.popViewController(animated: true)
        delegate.didDismiss(in: self)
    }

    func signedTransactionSelected(in controller: WalletConnectSessionViewController) {
        //no op
    }
}
