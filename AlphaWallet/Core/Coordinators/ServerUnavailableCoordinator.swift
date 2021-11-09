//
//  ServerUnavailableCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 05.03.2021.
//

import UIKit
import PromiseKit

class ServerUnavailableCoordinator: Coordinator {
    var coordinators: [Coordinator] = []

    private let navigationController: UINavigationController
    private var retainCycle: ServerUnavailableCoordinator?
    private let (promiseToReturn, seal) = Promise<Void>.pending()
    private let servers: [RPCServer]

    init(navigationController: UINavigationController, servers: [RPCServer], coordinator: Coordinator) {
        self.navigationController = navigationController
        self.servers = servers

        retainCycle = self

        promiseToReturn.ensure {
            // ensure we break the retain cycle
            self.retainCycle = nil
            coordinator.removeCoordinator(self)
        }.cauterize()
        
        addCoordinator(self)
    }

    func start() -> Promise<Void> {
        guard let keyWindow = UIApplication.shared.firstKeyWindow, !servers.isEmpty else { return promiseToReturn }

        let message: String
        if servers.count == 1 {
            message = R.string.localizable.serverWarningServerIsDisabled(servers[0].name)
        } else {
            let value = servers.map { $0.name }.joined(separator: ", ")
            message = R.string.localizable.serverWarningServersAreDisabled(value)
        }

        if let controller = keyWindow.rootViewController?.presentedViewController {
            controller.displayError(message: message) {
                self.seal.fulfill(())
            }
        } else {
            navigationController.displayError(message: message) {
                self.seal.fulfill(())
            }
        }

        return promiseToReturn
    } 
}
