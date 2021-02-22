//
//  WalletConnectToSessionCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.02.2021.
//

import UIKit

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
        presentationNavigationController.present(navigationController, animated: false)
        viewController.configure(for: viewModel)
        viewController.reloadView()
    }

    func dissmissAnimated(completion: @escaping () -> Void) {
        viewController.dismissViewAnimated {
            //Needs a strong self reference otherwise `self` might have been removed by its owner by the time animation completes and the `completion` block not called
            self.navigationController.dismiss(animated: true, completion: completion)
        }
    }
}

extension WalletConnectToSessionCoordinator: WalletConnectToSessionViewControllerDelegate {

    func changeConnectionServerSelected(in controller: WalletConnectToSessionViewController) {
        showAvailableToConnectServers(completion: { [weak self] result in
            guard let strongSelf = self else { return }

            switch result {
            case .connect(let server):
                strongSelf.serverToConnect = server
                strongSelf.viewModel.set(serverToConnect: server)
            case .cancel:
                break
            }

            strongSelf.viewController.configure(for: strongSelf.viewModel)
            strongSelf.viewController.reloadView()
        })
    }

    func controller(_ controller: WalletConnectToSessionViewController, continueButtonTapped sender: UIButton) {
        dissmissAnimated(completion: {
            guard let delegate = self.delegate else { return }

            delegate.coordinator(self, didCompleteWithConnection: .connect(self.serverToConnect))
        })
    }

    func didClose(in controller: WalletConnectToSessionViewController) {
        navigationController.dismiss(animated: false) { [weak self] in
            guard let strongSelf = self, let delegate = strongSelf.delegate else { return }

            delegate.coordinator(strongSelf, didCompleteWithConnection: .cancel)
        }
    }

    private func showAvailableToConnectServers(completion: @escaping (WalletConnectServer.ConnectionChoice) -> Void) {
        let style: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .actionSheet
        let alertViewController = UIAlertController(title: connection.name, message: R.string.localizable.walletConnectStart(connection.url.absoluteString), preferredStyle: style)
        for each in serverChoices {
            let action = UIAlertAction(title: each.name, style: .default) { _ in
                completion(.connect(each))
            }
            alertViewController.addAction(action)
        }

        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in
            completion(.cancel)
        }
        alertViewController.addAction(cancelAction)

        navigationController.present(alertViewController, animated: true)
    }

}
