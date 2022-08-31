//
//  ServerUnavailableCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 05.03.2021.
//

import UIKit
import PromiseKit
import AlphaWalletFoundation

protocol ServerUnavailableCoordinatorDelegate: AnyObject {
    func didDismiss(in coordinator: ServerUnavailableCoordinator)
}

class ServerUnavailableCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let servers: [RPCServer]
    private lazy var message: String? = {
        guard !servers.isEmpty else { return nil }

        if servers.count == 1 {
            return R.string.localizable.serverWarningServerIsDisabled(servers[0].name)
        } else {
            let value = servers.map { $0.name }.joined(separator: ", ")
            return R.string.localizable.serverWarningServersAreDisabled(value)
        }
    }()

    var coordinators: [Coordinator] = []
    weak var delegate: ServerUnavailableCoordinatorDelegate?

    init(navigationController: UINavigationController, servers: [RPCServer]) {
        self.navigationController = navigationController
        self.servers = servers
    }

    func start() {
        guard let message = message else {
            delegate?.didDismiss(in: self)
            return
        }

        UIApplication.shared
            .presentedViewController(or: navigationController)
            .displayError(message: message, completion: {
                self.delegate?.didDismiss(in: self)
            })
    } 
}
