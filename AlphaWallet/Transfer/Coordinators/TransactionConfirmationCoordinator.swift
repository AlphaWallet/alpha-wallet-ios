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
    case tokenScriptTransaction(confirmType: ConfirmType, contract: AlphaWallet.Address, keystore: Keystore, functionCallMetaData: DecodedFunctionCall, ethPrice: Subscribable<Double>)
    case dappTransaction(confirmType: ConfirmType, keystore: Keystore, ethPrice: Subscribable<Double>)
    case sendFungiblesTransaction(confirmType: ConfirmType, keystore: Keystore, assetDefinitionStore: AssetDefinitionStore, amount: FungiblesTransactionAmount, ethPrice: Subscribable<Double>)
    case sendNftTransaction(confirmType: ConfirmType, keystore: Keystore, ethPrice: Subscribable<Double>, tokenInstanceName: String?)
    case claimPaidErc875MagicLink(confirmType: ConfirmType, keystore: Keystore, price: BigUInt, ethPrice: Subscribable<Double>, numberOfTokens: UInt)
    var confirmType: ConfirmType {
        switch self {
        case .dappTransaction(let confirmType, _, _), .sendFungiblesTransaction(let confirmType, _, _, _, _), .sendNftTransaction(let confirmType, _, _, _), .tokenScriptTransaction(let confirmType, _, _, _, _), .claimPaidErc875MagicLink(let confirmType, _, _, _, _):
            return confirmType
        }
    }

    var keystore: Keystore {
        switch self {
        case .dappTransaction(_, let keystore, _), .sendFungiblesTransaction(_, let keystore, _, _, _), .sendNftTransaction(_, let keystore, _, _), .tokenScriptTransaction(_, _, let keystore, _, _), .claimPaidErc875MagicLink(_, let keystore, _, _, _):
            return keystore
        }
    }

    var ethPrice: Subscribable<Double> {
        switch self {
        case .dappTransaction(_, _, let ethPrice), .sendFungiblesTransaction(_, _, _, _, let ethPrice), .sendNftTransaction(_, _, let ethPrice, _), .tokenScriptTransaction(_, _, _, _, let ethPrice), .claimPaidErc875MagicLink(_, _, _, let ethPrice, _):
            return ethPrice
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
    case sentRawTransaction(id: String, original: String)
}

protocol TransactionConfirmationCoordinatorDelegate: class {
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didCompleteTransaction result: TransactionConfirmationResult)
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: AnyError)
    func didClose(in coordinator: TransactionConfirmationCoordinator)
}

class TransactionConfirmationCoordinator: Coordinator {
    private let configuration: TransactionConfirmationConfiguration
    let presentationNavigationController: UINavigationController
    private lazy var viewModel: TransactionConfirmationViewModel = .init(configurator: configurator, configuration: configuration)
    private lazy var confirmationViewController: TransactionConfirmationViewController = {
        let controller = TransactionConfirmationViewController(viewModel: viewModel)
        controller.delegate = self
        return controller
    }()
    private weak var configureTransactionViewController: ConfigureTransactionViewController?
    private let configurator: TransactionConfigurator
    private let analyticsCoordinator: AnalyticsCoordinator
    lazy var navigationController: UINavigationController = {
        let controller = UINavigationController(rootViewController: confirmationViewController)
        controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = .crossDissolve
        controller.view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        return controller
    }()

    var coordinators: [Coordinator] = []
    weak var delegate: TransactionConfirmationCoordinatorDelegate?

    init(navigationController: UINavigationController, session: WalletSession, transaction: UnconfirmedTransaction, configuration: TransactionConfirmationConfiguration, analyticsCoordinator: AnalyticsCoordinator) {
        configurator = TransactionConfigurator(session: session, transaction: transaction)
        self.configuration = configuration
        self.analyticsCoordinator = analyticsCoordinator
        presentationNavigationController = navigationController
    }

    func start(fromSource source: Analytics.TransactionConfirmationSource) {
        presentationNavigationController.present(navigationController, animated: false)
        configurator.delegate = self
        configurator.start()
        confirmationViewController.reloadView()

        analyticsCoordinator.log(navigation: Analytics.Navigation.actionSheetForTransactionConfirmation, properties: [Analytics.Properties.source.rawValue: source.rawValue])
    }

    func close(completion: @escaping () -> Void) {
        confirmationViewController.dismissViewAnimated {
            //Needs a strong self reference otherwise `self` might have been removed by its owner by the time animation completes and the `completion` block not called
            self.navigationController.dismiss(animated: true, completion: completion)
        }
    }

    func close() -> Promise<Void> {
        return Promise { seal in
            self.close {
                seal.fulfill(())
            }
        }
    }

    private func showFeedbackOnSuccess() {
        UINotificationFeedbackGenerator.show(feedbackType: .success)
    }
}

extension TransactionConfirmationCoordinator: TransactionConfirmationViewControllerDelegate {

    func didClose(in controller: TransactionConfirmationViewController) {
        analyticsCoordinator.log(action: Analytics.Action.cancelsTransactionInActionSheet)
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
            self.logAnalytics()
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

    private func logAnalytics() {
        let speedType: Analytics.TransactionConfirmationSpeedType
        switch configurator.selectedConfigurationType {
        case .slow:
            speedType = .slow
        case .standard:
            speedType = .standard
        case .fast:
            speedType = .fast
        case .rapid:
            speedType = .rapid
        case .custom:
            speedType = .custom
        }

        let transactionType: Analytics.TransactionType
        if let functionCallMetaData = DecodedFunctionCall(data: configurator.currentConfiguration.data) {
            switch functionCallMetaData.type {
            case .erc20Transfer:
                transactionType = .erc20Transfer
            case .nativeCryptoTransfer:
                transactionType = .nativeCryptoTransfer
            case .others:
                transactionType = .unknown
            }
        } else if configurator.currentConfiguration.data.isEmpty {
            transactionType = .nativeCryptoTransfer
        } else {
            transactionType = .unknown
        }

        analyticsCoordinator.log(action: Analytics.Action.confirmsTransactionInActionSheet, properties: [
            Analytics.Properties.speedType.rawValue: speedType.rawValue,
            Analytics.Properties.chain.rawValue: configurator.session.server.chainID,
            Analytics.Properties.transactionType.rawValue: transactionType.rawValue,
        ])
        if configurator.session.server.isTestnet {
            analyticsCoordinator.incrementUser(property: Analytics.UserProperties.testnetTransactionCount, by: 1)
        } else {
            analyticsCoordinator.incrementUser(property: Analytics.UserProperties.transactionCount, by: 1)
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

    func controllerDidTapEdit(_ controller: TransactionConfirmationViewController) {
        showConfigureTransactionViewController(configurator)
    }

    private func showConfigureTransactionViewController(_ configurator: TransactionConfigurator) {
        let controller = ConfigureTransactionViewController(viewModel: .init(configurator: configurator, ethPrice: configuration.ethPrice))
        controller.delegate = self
        navigationController.pushViewController(controller, animated: true)
        configureTransactionViewController = controller
    }
}

extension TransactionConfirmationCoordinator: ConfigureTransactionViewControllerDelegate {
    func didSavedToUseDefaultConfigurationType(_ configurationType: TransactionConfigurationType, in viewController: ConfigureTransactionViewController) {
        configurator.chooseDefaultConfigurationType(configurationType)
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
        confirmationViewController.reloadViewWithCurrentBalanceValue()
    }

    func gasLimitEstimateUpdated(to estimate: BigInt, in configurator: TransactionConfigurator) {
        configureTransactionViewController?.configure(withEstimatedGasLimit: estimate)
        confirmationViewController.reloadViewWithGasChanges()
        confirmationViewController.reloadViewWithCurrentBalanceValue()
    }

    func gasPriceEstimateUpdated(to estimate: BigInt, in configurator: TransactionConfigurator) {
        configureTransactionViewController?.configure(withEstimatedGasPrice: estimate, configurator: configurator)
        confirmationViewController.reloadViewWithGasChanges()
        confirmationViewController.reloadViewWithCurrentBalanceValue()
    }

    func updateNonce(to nonce: Int, in configurator: TransactionConfigurator) {
        configureTransactionViewController?.configure(nonce: nonce, configurator: configurator)
    }
}
