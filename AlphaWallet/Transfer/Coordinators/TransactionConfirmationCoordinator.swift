//
//  TransactionConfirmationCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.08.2020.
//

import UIKit
import BigInt
import PromiseKit
import AlphaWalletFoundation

protocol TransactionConfirmationCoordinatorDelegate: CanOpenURL, SendTransactionDelegate, BuyCryptoDelegate {
    func didFinish(_ result: ConfirmResult, in coordinator: TransactionConfirmationCoordinator)
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: Error)
    func didClose(in coordinator: TransactionConfirmationCoordinator)
}

class TransactionConfirmationCoordinator: Coordinator {
    private let configuration: TransactionType.Configuration
    private lazy var viewModel: TransactionConfirmationViewModel = .init(configurator: configurator, configuration: configuration, assetDefinitionStore: assetDefinitionStore, domainResolutionService: domainResolutionService, tokensService: tokensService)
    private lazy var rootViewController: TransactionConfirmationViewController = {
        let controller = TransactionConfirmationViewController(viewModel: viewModel)
        controller.delegate = self
        return controller
    }()
    private lazy var hostViewController: FloatingPanelController = {
        let panel = FloatingPanelController(isPanEnabled: false)
        panel.layout = SelfSizingPanelLayout(referenceGuide: .superview)
        panel.shouldDismissOnBackdrop = true
        panel.delegate = self
        panel.set(contentViewController: rootViewController)

        return panel
    }()
    private weak var configureTransactionViewController: ConfigureTransactionViewController?
    private let configurator: TransactionConfigurator
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainResolutionServiceType
    private var canBeDismissed = true
    private var server: RPCServer { configurator.session.server }
    private let navigationController: UIViewController
    private let keystore: Keystore
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokensService: TokenViewModelState

    var coordinators: [Coordinator] = []
    weak var delegate: TransactionConfirmationCoordinatorDelegate?

    init(presentingViewController: UIViewController, session: WalletSession, transaction: UnconfirmedTransaction, configuration: TransactionType.Configuration, analytics: AnalyticsLogger, domainResolutionService: DomainResolutionServiceType, keystore: Keystore, assetDefinitionStore: AssetDefinitionStore, tokensService: TokenViewModelState) throws {
        configurator = try TransactionConfigurator(session: session, analytics: analytics, transaction: transaction)
        self.keystore = keystore
        self.assetDefinitionStore = assetDefinitionStore
        self.configuration = configuration
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
        self.navigationController = presentingViewController
        self.tokensService = tokensService
    }

    func start(fromSource source: Analytics.TransactionConfirmationSource) {
        let presenter = UIApplication.shared.presentedViewController(or: navigationController)
        presenter.present(hostViewController, animated: true)

        configurator.delegate = self
        configurator.start()

        logStartActionSheetForTransactionConfirmation(source: source)
    }

    func close(completion: @escaping () -> Void) {
        navigationController.dismiss(animated: true, completion: completion)
    }

    private func showFeedbackOnSuccess() {
        UINotificationFeedbackGenerator.show(feedbackType: .success)
    }

    private func rectifyTransactionError(error: SendTransactionNotRetryableError) {
        analytics.log(action: Analytics.Action.rectifySendTransactionErrorInActionSheet, properties: [Analytics.Properties.type.rawValue: error.analyticsName])
        switch error {
        case .insufficientFunds:
            delegate?.buyCrypto(wallet: configurator.session.account, server: server, viewController: rootViewController, source: .transactionActionSheetInsufficientFunds)
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
}

extension TransactionConfirmationCoordinator: FloatingPanelControllerDelegate {
    func floatingPanelDidRemove(_ fpc: FloatingPanelController) {
        delegate?.didClose(in: self)
    }
}

extension TransactionConfirmationCoordinator: TransactionConfirmationViewControllerDelegate {

    func didInvalidateLayout(in controller: TransactionConfirmationViewController) {
        hostViewController.invalidateLayout()
    }

    func didClose(in controller: TransactionConfirmationViewController) {
        guard canBeDismissed else { return }

        analytics.log(action: Analytics.Action.cancelsTransactionInActionSheet)
        rootViewController.dismiss(animated: true) {
            self.delegate?.didClose(in: self)
        }
    }

    func controller(_ controller: TransactionConfirmationViewController, continueButtonTapped sender: UIButton) {
        sender.isEnabled = false
        canBeDismissed = false
        rootViewController.set(state: .pending)

        firstly { () -> Promise<ConfirmResult> in
            return sendTransaction()
        }.done { result in
            self.handleSendTransactionSuccessfully(result: result)
            self.logCompleteActionSheetForTransactionConfirmationSuccessfully()
        }.catch { error in
            self.logActionSheetForTransactionConfirmationFailed()
            //TODO remove delay which is currently needed because the starting animation may not have completed and internal state (whether animation is running) is in correct
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.rootViewController.set(state: .done(withError: true)) {
                    self.handleSendTransactionError(error)
                }
            }
        }.finally {
            sender.isEnabled = true
            self.canBeDismissed = true
        }
    }

    private func sendTransaction() -> Promise<ConfirmResult> {
        let prompt = R.string.localizable.keystoreAccessKeySign()
        let sender = SendTransaction(session: configurator.session, keystore: keystore, confirmType: configuration.confirmType, config: configurator.session.config, analytics: analytics, prompt: prompt)
        let transaction = configurator.formUnsignedTransaction()
        if configurator.session.config.development.shouldNotSendTransactions {
            return Promise(error: DevelopmentForcedError(message: "Did not send transaction because of development flag"))
        } else {
            return sender.send(transaction: transaction)
        }
    }

    private func handleSendTransactionSuccessfully(result: ConfirmResult) {
        switch result {
        case .sentTransaction(let tx):
            delegate?.didSendTransaction(tx, inCoordinator: self)
        case .sentRawTransaction, .signedTransaction:
            break
        }

        rootViewController.set(state: .done(withError: false)) {
            self.showFeedbackOnSuccess()
            self.delegate?.didFinish(result, in: self)
        }
    }

    private func handleSendTransactionError(_ error: Error) {
        switch error {
        case let e as SendTransactionNotRetryableError:
            let errorViewController = SendTransactionErrorViewController(server: server, analytics: analytics, error: e)
            errorViewController.delegate = self

            let panel = FloatingPanelController(isPanEnabled: false)
            panel.layout = SelfSizingPanelLayout(referenceGuide: .superview)
            panel.shouldDismissOnBackdrop = true
            panel.set(contentViewController: errorViewController)

            rootViewController.present(panel, animated: true)
        default:
            showError(error)
        }
    }

    private func showError(_ error: Error) {
        delegate?.coordinator(self, didFailTransaction: error)
    }

    func controllerDidTapEdit(_ controller: TransactionConfirmationViewController) {
        showConfigureTransactionViewController(configurator)
    }

    private func showConfigureTransactionViewController(_ configurator: TransactionConfigurator, recoveryMode: ConfigureTransactionViewModel.RecoveryMode = .none) {
        let controller = ConfigureTransactionViewController(viewModel: .init(configurator: configurator, recoveryMode: recoveryMode, service: tokensService))
        controller.delegate = self

        let navigationController = NavigationController(rootViewController: controller)
        navigationController.makePresentationFullScreenForiOS13Migration()
        controller.navigationItem.leftBarButtonItem = .closeBarButton(self, selector: #selector(configureTransactionDidDismiss))

        hostViewController.present(navigationController, animated: true)

        configureTransactionViewController = controller
    }

    @objc func configureTransactionDidDismiss() {
        configureTransactionViewController?.navigationController?.dismiss(animated: true)
    }
}

extension TransactionConfirmationCoordinator: ConfigureTransactionViewControllerDelegate {
    func didSavedToUseDefaultConfigurationType(_ configurationType: TransactionConfigurationType, in viewController: ConfigureTransactionViewController) {
        configurator.chooseDefaultConfigurationType(configurationType)
        viewController.navigationController?.dismiss(animated: true)
    }

    func didSaved(customConfiguration: TransactionConfiguration, in viewController: ConfigureTransactionViewController) {
        configurator.chooseCustomConfiguration(customConfiguration)
        viewController.navigationController?.dismiss(animated: true)
    }
}

extension TransactionConfirmationCoordinator: TransactionConfiguratorDelegate {
    func configurationChanged(in configurator: TransactionConfigurator) {
        //TODO: improve these few time view updates
        viewModel.reloadView()
        viewModel.updateBalance()
    }

    func gasLimitEstimateUpdated(to estimate: BigInt, in configurator: TransactionConfigurator) {
        configureTransactionViewController?.configure(withEstimatedGasLimit: estimate, configurator: configurator)

        //TODO: improve these few time view updates
        viewModel.reloadViewWithGasChanges()
        viewModel.updateBalance()
    }

    func gasPriceEstimateUpdated(to estimate: BigInt, in configurator: TransactionConfigurator) {
        configureTransactionViewController?.configure(withEstimatedGasPrice: estimate, configurator: configurator)

        //TODO: improve these few time view updates
        viewModel.reloadViewWithGasChanges()
        viewModel.updateBalance()
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

        let transactionType: Analytics.TransactionType = functional.analyticsTransactionType(fromConfiguration: configuration, data: configurator.currentConfiguration.data)
        let overridingRpcUrl: URL? = configurator.session.config.sendPrivateTransactionsProvider?.rpcUrl(forServer: configurator.session.server)
        let privateNetworkProvider: SendPrivateTransactionsProvider?
        if overridingRpcUrl == nil {
            privateNetworkProvider = nil
        } else {
            privateNetworkProvider = configurator.session.config.sendPrivateTransactionsProvider
        }
        var analyticsProperties: [String: AnalyticsEventPropertyValue] = [
            Analytics.Properties.speedType.rawValue: speedType.rawValue,
            Analytics.Properties.chain.rawValue: server.chainID,
            Analytics.Properties.transactionType.rawValue: transactionType.rawValue,
            //This is around for legacy reasons as we already send the provider if it's used
            Analytics.Properties.isPrivateNetworkEnabled.rawValue: privateNetworkProvider != nil,
        ]
        if let provider = privateNetworkProvider {
            analyticsProperties[Analytics.Properties.sendPrivateTransactionsProvider.rawValue] = provider.rawValue
            infoLog("Sent transaction with send private transactions provider: \(provider.rawValue)")
        } else {
            //no-op
            infoLog("Sent transaction publicly")
        }
        switch configuration {
        case .sendFungiblesTransaction(_, let amount):
            analyticsProperties[Analytics.Properties.isAllFunds.rawValue] = amount.isAllFunds
        case .tokenScriptTransaction, .dappTransaction, .walletConnect, .sendNftTransaction, .claimPaidErc875MagicLink, .speedupTransaction, .cancelTransaction, .swapTransaction, .approve:
            break
        }

        analytics.log(navigation: Analytics.Navigation.actionSheetForTransactionConfirmationSuccessful, properties: analyticsProperties)
        if server.isTestnet {
            analytics.incrementUser(property: Analytics.UserProperties.testnetTransactionCount, by: 1)
        } else {
            analytics.incrementUser(property: Analytics.UserProperties.transactionCount, by: 1)
        }
    }

    //TODO log a finite list of error types
    private func logActionSheetForTransactionConfirmationFailed() {
        analytics.log(navigation: Analytics.Navigation.actionSheetForTransactionConfirmationFailed)
    }

    private func logStartActionSheetForTransactionConfirmation(source: Analytics.TransactionConfirmationSource) {
        let transactionType: Analytics.TransactionType = functional.analyticsTransactionType(fromConfiguration: configuration, data: configurator.currentConfiguration.data)
        var analyticsProperties: [String: AnalyticsEventPropertyValue] = [
            Analytics.Properties.source.rawValue: source.rawValue,
            Analytics.Properties.chain.rawValue: server.chainID,
            Analytics.Properties.transactionType.rawValue: transactionType.rawValue,
        ]
        switch configuration {
        case .sendFungiblesTransaction(_, let amount):
            analyticsProperties[Analytics.Properties.isAllFunds.rawValue] = amount.isAllFunds
        case .tokenScriptTransaction, .dappTransaction, .walletConnect, .sendNftTransaction, .claimPaidErc875MagicLink, .speedupTransaction, .cancelTransaction, .swapTransaction, .approve:
            break
        }
        analytics.log(navigation: Analytics.Navigation.actionSheetForTransactionConfirmation, properties: analyticsProperties)
    }
}

extension TransactionConfirmationCoordinator: SendTransactionErrorViewControllerDelegate {
    func rectifyErrorButtonTapped(error: SendTransactionNotRetryableError, inController controller: SendTransactionErrorViewController) {
        controller.dismiss(animated: true) {
            self.rectifyTransactionError(error: error)
        }
    }

    func linkTapped(_ url: URL, forError error: SendTransactionNotRetryableError, inController controller: SendTransactionErrorViewController) {
        controller.dismiss(animated: true) {
            self.delegate?.didPressOpenWebPage(url, in: self.rootViewController)
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

extension TransactionConfirmationCoordinator {
    enum functional {}
}

fileprivate extension TransactionConfirmationCoordinator.functional {
    static func isSwapTransaction(configuration: TransactionType.Configuration) -> Bool {
        switch configuration {
        case .swapTransaction:
            return true
        case .sendFungiblesTransaction, .tokenScriptTransaction, .dappTransaction, .walletConnect, .sendNftTransaction, .claimPaidErc875MagicLink, .speedupTransaction, .cancelTransaction, .approve:
            return false
        }
    }

    static func analyticsTransactionType(fromConfiguration configuration: TransactionType.Configuration, data: Data) -> Analytics.TransactionType {
        if let functionCallMetaData = DecodedFunctionCall(data: data) {
            switch functionCallMetaData.type {
            case .erc1155SafeTransfer:
                return .unknown
            case .erc1155SafeBatchTransfer:
                return .unknown
            case .erc20Approve:
                return .erc20Approve
            case .erc20Transfer:
                return .erc20Transfer
            case .erc721ApproveAll:
                return .erc721ApproveAll
            case .nativeCryptoTransfer:
                return .nativeCryptoTransfer
            case .others:
                return .unknown
            }
        } else if data.isEmpty {
            return .nativeCryptoTransfer
        } else {
            if isSwapTransaction(configuration: configuration) {
                //TODO should probably log which DEX is used? But does it still map into this analytics event or should we have a different one?
                return .swap
            } else {
                return .unknown
            }
        }
    }
}
