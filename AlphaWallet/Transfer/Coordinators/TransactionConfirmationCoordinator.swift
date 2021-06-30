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
    case walletConnect(confirmType: ConfirmType, keystore: Keystore, ethPrice: Subscribable<Double>)
    case sendFungiblesTransaction(confirmType: ConfirmType, keystore: Keystore, assetDefinitionStore: AssetDefinitionStore, amount: FungiblesTransactionAmount, ethPrice: Subscribable<Double>)
    case sendNftTransaction(confirmType: ConfirmType, keystore: Keystore, ethPrice: Subscribable<Double>, tokenInstanceName: String?)
    case claimPaidErc875MagicLink(confirmType: ConfirmType, keystore: Keystore, price: BigUInt, ethPrice: Subscribable<Double>, numberOfTokens: UInt)
    case speedupTransaction(keystore: Keystore, ethPrice: Subscribable<Double>)
    case cancelTransaction(keystore: Keystore, ethPrice: Subscribable<Double>)
    var confirmType: ConfirmType {
        switch self {
        case .dappTransaction(let confirmType, _, _), .walletConnect(let confirmType, _, _), .sendFungiblesTransaction(let confirmType, _, _, _, _), .sendNftTransaction(let confirmType, _, _, _), .tokenScriptTransaction(let confirmType, _, _, _, _), .claimPaidErc875MagicLink(let confirmType, _, _, _, _):
            return confirmType
        case .speedupTransaction, .cancelTransaction:
            return .signThenSend
        }
    }

    var keystore: Keystore {
        switch self {
        case .dappTransaction(_, let keystore, _), .walletConnect(_, let keystore, _), .sendFungiblesTransaction(_, let keystore, _, _, _), .sendNftTransaction(_, let keystore, _, _), .tokenScriptTransaction(_, _, let keystore, _, _), .claimPaidErc875MagicLink(_, let keystore, _, _, _), .speedupTransaction(let keystore, _), .cancelTransaction(let keystore, _):
            return keystore
        }
    }

    var ethPrice: Subscribable<Double> {
        switch self {
        case .dappTransaction(_, _, let ethPrice), .walletConnect(_, _, let ethPrice), .sendFungiblesTransaction(_, _, _, _, let ethPrice), .sendNftTransaction(_, _, let ethPrice, _), .tokenScriptTransaction(_, _, _, _, let ethPrice), .claimPaidErc875MagicLink(_, _, _, let ethPrice, _), .speedupTransaction(_, let ethPrice), .cancelTransaction(_, let ethPrice):
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

protocol TransactionConfirmationCoordinatorDelegate: class, CanOpenURL {
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didCompleteTransaction result: TransactionConfirmationResult)
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: AnyError)
    func didClose(in coordinator: TransactionConfirmationCoordinator)
}

class TransactionConfirmationCoordinator: Coordinator {
    private let configuration: TransactionConfirmationConfiguration
    private lazy var viewModel: TransactionConfirmationViewModel = .init(configurator: configurator, configuration: configuration)
    private lazy var confirmationViewController: TransactionConfirmationViewController = {
        let controller = TransactionConfirmationViewController(viewModel: viewModel)
        controller.delegate = self
        return controller
    }()
    private weak var configureTransactionViewController: ConfigureTransactionViewController?
    private let configurator: TransactionConfigurator
    private let analyticsCoordinator: AnalyticsCoordinator

    private var server: RPCServer {
        configurator.session.server
    }

    let presentingViewController: UIViewController
    lazy var navigationController: UINavigationController = {
        let controller = UINavigationController(rootViewController: confirmationViewController)
        controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = .crossDissolve
        controller.view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        return controller
    }()

    var coordinators: [Coordinator] = []
    weak var delegate: TransactionConfirmationCoordinatorDelegate?

    init(presentingViewController: UIViewController, session: WalletSession, transaction: UnconfirmedTransaction, configuration: TransactionConfirmationConfiguration, analyticsCoordinator: AnalyticsCoordinator) {
        configurator = TransactionConfigurator(session: session, transaction: transaction)
        self.configuration = configuration
        self.analyticsCoordinator = analyticsCoordinator
        self.presentingViewController = presentingViewController
    }

    func start(fromSource source: Analytics.TransactionConfirmationSource) {
        guard let keyWindow = UIApplication.shared.keyWindow else { return }

        if let controller = keyWindow.rootViewController?.presentedViewController {
            controller.present(navigationController, animated: false)
        } else {
            presentingViewController.present(navigationController, animated: false)
        }

        configurator.delegate = self
        configurator.start()
        confirmationViewController.reloadView()

        logStartActionSheetForTransactionConfirmation(source: source)
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

    private func rectifyTransactionError(error: SendTransactionNotRetryableError) {
        analyticsCoordinator.log(action: Analytics.Action.rectifySendTransactionErrorInActionSheet, properties: [Analytics.Properties.type.rawValue: error.analyticsName])
        switch error {
        case .insufficientFunds:
            let ramp = Ramp(account: configurator.session.account)
            if let url = ramp.url(token: TokenActionsServiceKey(tokenObject: TokensDataStore.etherToken(forServer: server))) {
                delegate?.didPressOpenWebPage(url, in: confirmationViewController)
            } else {
                let fallbackUrl = URL(string: "https://alphawallet.com/browser-item-category/utilities/")!
                delegate?.didPressOpenWebPage(fallbackUrl, in: confirmationViewController)
            }
        case .nonceTooLow:
            showConfigureTransactionViewController(configurator, recoveryMode: .invalidNonce)
        case .gasPriceTooLow:
            showConfigureTransactionViewController(configurator)
        case .gasLimitTooLow:
            showConfigureTransactionViewController(configurator)
        case .gasLimitTooHigh:
            showConfigureTransactionViewController(configurator)
        case .possibleChainIdMismatch:
            break
        case .executionReverted:
            break
        }
    }

    private func askUserToRateAppOrSubscribeToNewsletter() {
        let coordinator = HelpUsCoordinator(navigationController: navigationController, appTracker: AppTracker())
        coordinator.rateUsOrSubscribeToNewsletter()
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
            self.logCompleteActionSheetForTransactionConfirmationSuccessfully()
            self.askUserToRateAppOrSubscribeToNewsletter()
        }.catch { error in
            self.logActionSheetForTransactionConfirmationFailed()
            //TODO remove delay which is currently needed because the starting animation may not have completed and internal state (whether animation is running) is in correct
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.confirmationViewController.set(state: .done(withError: true)) {
                    self.handleSendTransactionError(error)
                }
            }
        }.finally {
            sender.isEnabled = true
            self.confirmationViewController.canBeDismissed = true
        }
    }

    private func sendTransaction() -> Promise<ConfirmResult> {
        let coordinator = SendTransactionCoordinator(session: configurator.session, keystore: configuration.keystore, confirmType: configuration.confirmType, config: configurator.session.config)
        let transaction = configurator.formUnsignedTransaction()
        return coordinator.send(transaction: transaction)
    }

    private func showSuccess(result: ConfirmResult) {
        confirmationViewController.set(state: .done(withError: false)) {
            self.showFeedbackOnSuccess()
            self.delegate?.coordinator(self, didCompleteTransaction: .confirmationResult(result))
        }
    }

    private func handleSendTransactionError(_ error: Error) {
        switch error {
        case let e as SendTransactionNotRetryableError:
            let errorViewController = SendTransactionErrorViewController(server: server, error: e)
            errorViewController.delegate = self
            let controller = UINavigationController(rootViewController: errorViewController)
            controller.modalPresentationStyle = .overFullScreen
            controller.modalTransitionStyle = .crossDissolve
            controller.view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            confirmationViewController.present(controller, animated: true)
        default:
            showError(error)
        }
    }

    private func showError(_ error: Error) {
        delegate?.coordinator(self, didFailTransaction: AnyError(error))
    }

    func controllerDidTapEdit(_ controller: TransactionConfirmationViewController) {
        showConfigureTransactionViewController(configurator)
    }

    private func showConfigureTransactionViewController(_ configurator: TransactionConfigurator, recoveryMode: ConfigureTransactionViewModel.RecoveryMode = .none) {
        let controller = ConfigureTransactionViewController(viewModel: .init(configurator: configurator, ethPrice: configuration.ethPrice, recoveryMode: recoveryMode))
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

// MARK: Analytics
extension TransactionConfirmationCoordinator {
    private func logCompleteActionSheetForTransactionConfirmationSuccessfully() {
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
            case .erc20Approve:
                transactionType = .erc20Approve
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

        var analyticsProperties: [String: AnalyticsEventPropertyValue] = [
            Analytics.Properties.speedType.rawValue: speedType.rawValue,
            Analytics.Properties.chain.rawValue: server.chainID,
            Analytics.Properties.transactionType.rawValue: transactionType.rawValue,
            Analytics.Properties.isTaiChiEnabled.rawValue: configurator.session.config.useTaiChiNetwork,
        ]
        switch configuration {
        case .sendFungiblesTransaction(_, _, _, amount: let amount, _):
            analyticsProperties[Analytics.Properties.isAllFunds.rawValue] = amount.isAllFunds
        case .tokenScriptTransaction, .dappTransaction, .walletConnect, .sendNftTransaction, .claimPaidErc875MagicLink, .speedupTransaction, .cancelTransaction:
            break
        }

        analyticsCoordinator.log(navigation: Analytics.Navigation.actionSheetForTransactionConfirmationSuccessful, properties: analyticsProperties)
        if server.isTestnet {
            analyticsCoordinator.incrementUser(property: Analytics.UserProperties.testnetTransactionCount, by: 1)
        } else {
            analyticsCoordinator.incrementUser(property: Analytics.UserProperties.transactionCount, by: 1)
        }
    }

    //TODO log a finite list of error types
    private func logActionSheetForTransactionConfirmationFailed() {
        analyticsCoordinator.log(navigation: Analytics.Navigation.actionSheetForTransactionConfirmationFailed)
    }

    private func logStartActionSheetForTransactionConfirmation(source: Analytics.TransactionConfirmationSource) {
        var analyticsProperties: [String: AnalyticsEventPropertyValue] = [Analytics.Properties.source.rawValue: source.rawValue]
        switch configuration {
        case .sendFungiblesTransaction(_, _, _, amount: let amount, _):
            analyticsProperties[Analytics.Properties.isAllFunds.rawValue] = amount.isAllFunds
        case .tokenScriptTransaction, .dappTransaction, .walletConnect, .sendNftTransaction, .claimPaidErc875MagicLink, .speedupTransaction, .cancelTransaction:
            break
        }
        analyticsCoordinator.log(navigation: Analytics.Navigation.actionSheetForTransactionConfirmation, properties: analyticsProperties)
    }
}

extension TransactionConfirmationCoordinator: SendTransactionErrorViewControllerDelegate {
    func rectifyErrorButtonTapped(error: SendTransactionNotRetryableError, inController controller: SendTransactionErrorViewController) {
        controller.dismiss(animated: false) {
            self.rectifyTransactionError(error: error)
        }
    }

    func linkTapped(_ url: URL, forError error: SendTransactionNotRetryableError, inController controller: SendTransactionErrorViewController) {
        controller.dismiss(animated: false) {
            self.delegate?.didPressOpenWebPage(url, in: self.confirmationViewController)
        }
    }

    func controllerDismiss(_ controller: SendTransactionErrorViewController) {
        controller.dismiss(animated: true)
    }
}

extension SendTransactionNotRetryableError {
    var analyticsName: String {
        switch self {
        case .insufficientFunds:
            return "insufficientFunds"
        case .nonceTooLow:
            return "nonceTooLow"
        case .gasPriceTooLow:
            return "gasPriceTooLow"
        case .gasLimitTooLow:
            return "gasLimitTooLow"
        case .gasLimitTooHigh:
            return "gasLimitTooHigh"
        case .possibleChainIdMismatch:
            return "possibleChainIdMismatch"
        case .executionReverted:
            return "executionReverted"
        }
    }
}
