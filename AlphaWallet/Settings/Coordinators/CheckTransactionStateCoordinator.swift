//
//  CheckTransactionStateCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.03.2022.
//

import Foundation
import AlphaWalletFoundation
import Combine

protocol CheckTransactionStateCoordinatorDelegate: AnyObject {
    func didComplete(coordinator: CheckTransactionStateCoordinator)
}

class CheckTransactionStateCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let config: Config
    private let sessions: ServerDictionary<WalletSession>
    private var serverSelection: ServerSelection = .server(server: .server(.main))
    private lazy var rootViewController: CheckTransactionStateViewController = {
        let viewModel = CheckTransactionStateViewModel(serverSelection: serverSelection)
        let viewController = CheckTransactionStateViewController(viewModel: viewModel)
        viewController.configure(viewModel: viewModel)
        viewController._delegate = self

        return viewController
    }()
    private var cancellable = Set<AnyCancellable>()

    var coordinators: [Coordinator] = []
    weak var delegate: CheckTransactionStateCoordinatorDelegate?

    init(navigationController: UINavigationController, config: Config, sessions: ServerDictionary<WalletSession>) {
        self.navigationController = navigationController
        self.config = config
        self.sessions = sessions
    }

    func start() {
        navigationController.present(rootViewController, animated: false)
    }

    private func displayErrorMessage(_ message: String, title: String? = .none) {
        UIApplication.shared
            .presentedViewController(or: navigationController)
            .displaySuccess(title: title, message: message)
    }
}

extension CheckTransactionStateCoordinator: SelectTransactionHashViewControllerDelegate {

    func didSelectedCheckTransactionStatus(in viewController: CheckTransactionStateViewController, transactionHash: String) {
        guard let server = serverSelection.asServersArray.first, let session = sessions[safe: server] else { return }

        rootViewController.set(isActionButtonEnable: false)

        session.blockchainProvider
            .transactionsStatePublisher(hash: transactionHash)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    self.displayErrorMessage(R.string.localizable.checkTransactionStateError(error.prettyError), title: R.string.localizable.error())
                }

                self.rootViewController.set(isActionButtonEnable: true)
            }, receiveValue: { state in
                self.displayErrorMessage(R.string.localizable.checkTransactionStateComplete(state.description))
            }).store(in: &cancellable)
    }

    func didClose(in viewController: CheckTransactionStateViewController) {
        delegate?.didComplete(coordinator: self)
    }

    func didSelectServerSelected(in viewController: CheckTransactionStateViewController) {
        let serverChoices: [RPCServerOrAuto] = ServersCoordinator.serversOrdered
            .filter { RPCServer.availableServers.contains($0) }
            .map { .server($0) }

        let viewModel = ServersViewModel(servers: serverChoices, selectedServers: serverSelection.asServersOrAnyArray, displayWarningFooter: false)
        let coordinator = ServersCoordinator(viewModel: viewModel, navigationController: rootViewController)
        coordinator.delegate = self
        coordinator.start()
        addCoordinator(coordinator)
    }
}

extension CheckTransactionStateCoordinator: ServersCoordinatorDelegate {
    func didSelectServer(selection: ServerSelection, in coordinator: ServersCoordinator) {
        serverSelection = selection

        let viewModel = CheckTransactionStateViewModel(serverSelection: selection)
        rootViewController.configure(viewModel: viewModel)

        removeCoordinator(coordinator)
    }

    func didClose(in coordinator: ServersCoordinator) {
        removeCoordinator(coordinator)
    }
}
