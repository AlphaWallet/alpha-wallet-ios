//
//  CheckTransactionStateCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.03.2022.
//

import Foundation
import PromiseKit
import web3swift
import AlphaWalletFoundation

protocol CheckTransactionStateCoordinatorDelegate: class {
    func didComplete(coordinator: CheckTransactionStateCoordinator)
}

final class TransactionStateFetcher {
    func fetchTransactionsState(server: RPCServer, transactionHash: String) -> Promise <TransactionState> {
        guard let web3 = try? getCachedWeb3(forServer: server, timeout: 6) else {
            return .init(error: PMKError.cancelled)
        }

        return web3swift.web3.Eth(provider: web3.provider, web3: web3)
            .getTransactionReceiptPromise(transactionHash)
            .map { TransactionState(status: $0.status) }
    }
}

class CheckTransactionStateCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let config: Config
    private var serverSelection: ServerSelection = .server(server: .server(.main))
    private lazy var rootViewController: CheckTransactionStateViewController = {
        let viewModel = CheckTransactionStateViewModel(serverSelection: serverSelection)
        let viewController = CheckTransactionStateViewController(viewModel: viewModel)
        viewController.configure(viewModel: viewModel)
        viewController._delegate = self

        return viewController
    }()

    var coordinators: [Coordinator] = []
    weak var delegate: CheckTransactionStateCoordinatorDelegate?

    init(navigationController: UINavigationController, config: Config) {
        self.navigationController = navigationController
        self.config = config
    }

    func start() {
        navigationController.present(rootViewController, animated: false)
    }

    private var presentationViewController: UIViewController {
        guard let keyWindow = UIApplication.shared.firstKeyWindow else { return navigationController }

        if let controller = keyWindow.rootViewController?.presentedViewController {
            return controller
        } else {
            return navigationController
        }
    }

    private func displayErrorMessage(_ message: String, title: String? = .none) {
        presentationViewController.displaySuccess(title: title, message: message)
    }
}

extension CheckTransactionStateCoordinator: SelectTransactionHashViewControllerDelegate {

    func didSelectedCheckTransactionStatus(in viewController: CheckTransactionStateViewController, transactionHash: String) {
        guard let server = serverSelection.asServersArray.first else { return }

        rootViewController.set(isActionButtonEnable: false)

        TransactionStateFetcher()
            .fetchTransactionsState(server: server, transactionHash: transactionHash)
            .done { state in
                self.displayErrorMessage(R.string.localizable.checkTransactionStateComplete(state.description))
            }.catch { error in
                self.displayErrorMessage(R.string.localizable.checkTransactionStateError(error.prettyError), title: R.string.localizable.error())
            }.finally {
                self.rootViewController.set(isActionButtonEnable: true)
            }
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

extension TransactionState {
    var description: String {
        switch self {
        case .completed: return R.string.localizable.transactionStateCompleted()
        case .pending: return R.string.localizable.transactionStatePending()
        case .error: return R.string.localizable.transactionStateError()
        case .failed: return R.string.localizable.transactionStateFailed()
        case .unknown: return R.string.localizable.transactionStateUnknown()
        }
    }
}

extension CheckTransactionStateCoordinator: ServersCoordinatorDelegate {
    func didSelectServer(selection: ServerSelection, in coordinator: ServersCoordinator) {
        serverSelection = selection
        coordinator.navigationController.popViewController(animated: true) { [weak self] in
            guard let strongSelf = self else { return }

            let viewModel = CheckTransactionStateViewModel(serverSelection: selection)
            strongSelf.rootViewController.configure(viewModel: viewModel)

            strongSelf.removeCoordinator(coordinator)
        }
    }

    func didSelectDismiss(in coordinator: ServersCoordinator) {
        coordinator.navigationController.popViewController(animated: true)
        removeCoordinator(coordinator)
    }

}
