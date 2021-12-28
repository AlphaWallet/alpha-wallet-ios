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
    private let server: RPCServer

    init(navigationController: UINavigationController, server: RPCServer, coordinator: Coordinator) {
        self.navigationController = navigationController
        self.server = server

        retainCycle = self

        promiseToReturn.ensure {
            // ensure we break the retain cycle
            self.retainCycle = nil
            coordinator.removeCoordinator(self)
        }.cauterize()
        
        addCoordinator(self)
    }

    func start() -> Promise<Void> {
        guard let keyWindow = UIApplication.shared.firstKeyWindow else { return promiseToReturn }

        let message = R.string.localizable.serverWarningServerIsDisabled(server.name)
        
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
