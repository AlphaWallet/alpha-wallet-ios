//
//  WalletConnectToSessionCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.02.2021.
//

import UIKit
import PromiseKit

protocol WalletConnectToSessionCoordinatorDelegate: class {
    func coordinator(_ coordinator: WalletConnectToSessionCoordinator, didCompleteWithConnection result: WalletConnectServer.ConnectionChoice)
}

class WalletConnectToSessionCoordinator: Coordinator {
    var coordinators: [Coordinator] = []

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
    weak var delegate: WalletConnectToSessionCoordinatorDelegate?

    init(connection: WalletConnectConnection, navigationController: UINavigationController, serverChoices: [RPCServer]) {
        self.connection = connection
        self.serverToConnect = connection.server ?? .main
        self.presentationNavigationController = navigationController
        self.serverChoices = serverChoices
    }

    func start() {
        guard let keyWindow = UIApplication.shared.keyWindow else { return }

        if let controller = keyWindow.rootViewController?.presentedViewController {
            controller.present(navigationController, animated: false)
        } else {
            presentationNavigationController.present(navigationController, animated: false)
        }

        viewController.configure(for: viewModel)
        viewController.reloadView()
    }

    deinit {
        print("\(self).deinit")
    }

    func dissmissAnimated(animated: Bool = true) -> Promise<Void> {
        return Promise<Void> { seal in
            viewController.dismissViewAnimated {
                //Needs a strong self reference otherwise `self` might have been removed by its owner by the time animation completes and the `completion` block not called
                self.navigationController.dismiss(animated: animated, completion: {
                    seal.fulfill(())
                })
            }
        }
    }
}

extension WalletConnectToSessionCoordinator: WalletConnectToSessionViewControllerDelegate {

    func changeConnectionServerSelected(in controller: WalletConnectToSessionViewController) {
        let servers = serverChoices.compactMap { RPCServerOrAuto.server($0) }
        let viewModel = ServersViewModel(servers: servers, selectedServer: .auto, displayWarningFooter: false)

        ServersCoordinator.promise(navigationController, viewModel: viewModel, coordinator: self).done { server in
            self.serverToConnect = server
            self.viewModel.set(serverToConnect: server)
        }.cauterize().finally {
            self.viewController.configure(for: self.viewModel)
            self.viewController.reloadView()
        }
    }

    func controller(_ controller: WalletConnectToSessionViewController, continueButtonTapped sender: UIButton) {
        firstly {
            dissmissAnimated(animated: true)
        }.done { _ in
            guard let delegate = self.delegate else { return }

            delegate.coordinator(self, didCompleteWithConnection: .connect(self.serverToConnect))
        }.cauterize()
    }

    func didClose(in controller: WalletConnectToSessionViewController) {
        firstly {
            dissmissAnimated(animated: false)
        }.done { _ in
            guard let delegate = self.delegate else { return }

            delegate.coordinator(self, didCompleteWithConnection: .cancel)
        }.cauterize()
    }
}
