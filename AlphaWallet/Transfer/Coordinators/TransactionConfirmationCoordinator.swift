//
//  TransactionConfirmationCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.08.2020.
//

import UIKit
import BigInt
import PromiseKit
import Result

enum TransactionConfirmationConfiguration {
    case tokenScriptTransaction(confirmType: ConfirmType, contract: AlphaWallet.Address, keystore: Keystore)
    case dappTransaction(confirmType: ConfirmType, keystore: Keystore)
    case sendFungiblesTransaction(confirmType: ConfirmType, keystore: Keystore, assetDefinitionStore: AssetDefinitionStore, amount: String, ethPrice: Subscribable<Double>)
    case sendNftTransaction(confirmType: ConfirmType, keystore: Keystore)

    var confirmType: ConfirmType {
        switch self {
        case .dappTransaction(let confirmType, _), .sendFungiblesTransaction(let confirmType, _, _, _, _), .sendNftTransaction(let confirmType, _), .tokenScriptTransaction(let confirmType, _, _):
            return confirmType
        }
    }

    var keystore: Keystore {
        switch self {
        case .dappTransaction(_, let keystore), .sendFungiblesTransaction(_, let keystore, _, _, _), .sendNftTransaction(_, let keystore), .tokenScriptTransaction(_, _, let keystore):
            return keystore
        }
    }
}

enum TransactionConfirmationResult {
    case confirmationResult(ConfirmResult)
    case noData
}

enum ConfirmType {
    case sign
    case signThenSend
}

enum ConfirmResult {
    case signedTransaction(Data)
    case sentTransaction(SentTransaction)
}

protocol TransactionConfirmationCoordinatorDelegate: class {
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didCompleteTransaction result: TransactionConfirmationResult)
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: AnyError)
    func didClose(in coordinator: TransactionConfirmationCoordinator)
}

class TransactionConfirmationCoordinator: Coordinator {
    private struct Parent {
        let navigationController: UINavigationController
    }

    private let configuration: TransactionConfirmationConfiguration
    private let parent: Parent

    private lazy var confirmationViewController: TransactionConfirmationViewController = {
        let controller = TransactionConfirmationViewController(viewModel: .init(configurator: configurator, configuration: configuration))
        controller.delegate = self
        return controller
    }()
    private weak var configureTransactionViewController: ConfigureTransactionViewController?
    private let configurator: TransactionConfigurator

    lazy var navigationController: UINavigationController = {
        let controller = UINavigationController(rootViewController: confirmationViewController)
        controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = .crossDissolve
        controller.view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        return controller
    }()

    var coordinators: [Coordinator] = []
    weak var delegate: TransactionConfirmationCoordinatorDelegate?

    init(navigationController: UINavigationController, session: WalletSession, transaction: UnconfirmedTransaction, configuration: TransactionConfirmationConfiguration) {
        configurator = TransactionConfigurator(session: session, transaction: transaction)
        self.configuration = configuration
        parent = Parent(navigationController: navigationController)
    }

    func start() {
        parent.navigationController.present(navigationController, animated: false)
        configurator.delegate = self
        configurator.start()
        confirmationViewController.reloadView()
    }

    func close(completion: @escaping () -> Void) {
        confirmationViewController.dismissViewAnimated(with: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.navigationController.dismiss(animated: true, completion: completion)
        })
    }

    private func showFeedbackOnSuccess() {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()
        //Hackish, but delay necessary because of the switch to and from user-presence for signing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            //TODO sound too
            feedbackGenerator.notificationOccurred(.success)
        }
    }
}

extension TransactionConfirmationCoordinator: TransactionConfirmationViewControllerDelegate {
    func didClose(in controller: TransactionConfirmationViewController) {
        navigationController.dismiss(animated: false) { [weak self] in
            guard let strongSelf = self, let delegate = strongSelf.delegate else { return }
            delegate.didClose(in: strongSelf)
        }
    }

    func controller(_ controller: TransactionConfirmationViewController, continueButtonTapped sender: UIButton) {
        sender.isEnabled = false
        confirmationViewController.canBeDismissed = false
        confirmationViewController.set(state: .pending)
        firstly {
            sendTransaction()
        }.done { result in
            self.showSuccess(result: result)
        }.catch { error in
            //TODO remove delay which is currently needed because the starting animation may not have completed and internal state (whether animation is running) is in correct
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.showError(error)
            }
        }.finally {
            sender.isEnabled = true
            self.confirmationViewController.canBeDismissed = true
        }
    }

    private func sendTransaction() -> Promise<ConfirmResult> {
        let coordinator = SendTransactionCoordinator(session: configurator.session, keystore: configuration.keystore, confirmType: configuration.confirmType)
        let transaction = configurator.formUnsignedTransaction()
        return coordinator.send(transaction: transaction)
    }

    private func showSuccess(result: ConfirmResult) {
        confirmationViewController.set(state: .done(withError: false)) {
            self.showFeedbackOnSuccess()
            self.delegate?.coordinator(self, didCompleteTransaction: .confirmationResult(result))
        }
    }

    private func showError(_ error: Error) {
        confirmationViewController.set(state: .done(withError: true)) {
            self.delegate?.coordinator(self, didFailTransaction: AnyError(error))
        }
    }

    func controller(_ controller: TransactionConfirmationViewController, editTransactionButtonTapped sender: UIButton) {
        showConfigureTransactionViewController(configurator, session: configurator.session)
    }

    private func showConfigureTransactionViewController(_ configurator: TransactionConfigurator, session: WalletSession) {
        let controller = ConfigureTransactionViewController(viewModel: .init(server: session.server, configurator: configurator, currencyRate: session.balanceCoordinator.currencyRate))
        controller.delegate = self
        navigationController.pushViewController(controller, animated: true)
        configureTransactionViewController = controller
    }
}

extension TransactionConfirmationCoordinator: ConfigureTransactionViewControllerDelegate {
    func didSavedToUseDefaultConfiguration(in viewController: ConfigureTransactionViewController) {
        configurator.chooseDefaultConfiguration()
        navigationController.popViewController(animated: true)
    }

    func didSaved(customConfiguration: TransactionConfiguration, in viewController: ConfigureTransactionViewController) {
        configurator.chooseCustomConfiguration(customConfiguration)
        navigationController.popViewController(animated: true)
    }
}

extension TransactionConfirmationCoordinator: TransactionConfiguratorDelegate {
    func configurationChanged(in configurator: TransactionConfigurator) {
        confirmationViewController.reloadView()
    }

    func gasLimitEstimateUpdated(to estimate: BigInt, in configurator: TransactionConfigurator) {
        configureTransactionViewController?.configure(withEstimatedGasLimit: estimate)
    }

    func gasPriceEstimateUpdated(to estimate: BigInt, in configurator: TransactionConfigurator) {
        configureTransactionViewController?.configure(withEstimatedGasPrice: estimate)
    }
}
