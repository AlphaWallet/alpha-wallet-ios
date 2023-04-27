//
//  ServerUnavailableCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 05.03.2021.
//

import UIKit
import AlphaWalletFoundation

protocol ServerUnavailableCoordinatorDelegate: AnyObject {
    func didDismiss(in coordinator: ServerUnavailableCoordinator, result: Swift.Result<Void, Error>)
}

enum ServerUnavailableError: Error {
    case messageIsEmpty
    case cancelled
}

class ServerUnavailableCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let disabledServers: [RPCServer]
    private let restartHandler: RestartQueueHandler
    private lazy var message: String? = {
        guard !disabledServers.isEmpty else { return nil }

        if disabledServers.count == 1 {
            return R.string.localizable.serverWarningServerIsDisabled(disabledServers[0].name)
        } else {
            let value = disabledServers.map { $0.name }.joined(separator: ", ")
            return R.string.localizable.serverWarningServersAreDisabled(value)
        }
    }()

    var coordinators: [Coordinator] = []
    weak var delegate: ServerUnavailableCoordinatorDelegate?

    init(navigationController: UINavigationController,
         disabledServers: [RPCServer],
         restartHandler: RestartQueueHandler) {

        self.restartHandler = restartHandler
        self.navigationController = navigationController
        self.disabledServers = disabledServers
    }

    func start() {
        guard let message = message else {
            delegate?.didDismiss(in: self, result: .failure(ServerUnavailableError.messageIsEmpty))
            return
        }

        Task { @MainActor in
            let result = await UIApplication.shared
                .presentedViewController(or: navigationController)
                .confirm(message: message, okTitle: "Enable and Connect")

            switch result {
            case .success:
                self.enabledDisabledServers()
                self.delegate?.didDismiss(in: self, result: .success(()))
            case .failure:
                self.delegate?.didDismiss(in: self, result: .failure(ServerUnavailableError.cancelled))
            }
        }
    }

    private func enabledDisabledServers() {
        let tasks = disabledServers.map { RestartTaskQueue.Task.enableServer($0) }
        tasks.forEach { restartHandler.add($0) }

        restartHandler.processTasks()
    }
}
