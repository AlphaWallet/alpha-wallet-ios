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
import AlphaWalletLogger
import Combine

protocol TransactionConfirmationCoordinatorDelegate: CanOpenURL, SendTransactionDelegate, BuyCryptoDelegate {
    func didFinish(_ result: ConfirmResult, in coordinator: TransactionConfirmationCoordinator)
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: Error)
    func didClose(in coordinator: TransactionConfirmationCoordinator)
}

class TransactionConfirmationCoordinator: Coordinator {
    private let configuration: TransactionType.Configuration

    private lazy var rootViewController: TransactionConfirmationViewController = {
        let viewModel = TransactionConfirmationViewModel.buildViewModel(
            configurator: configurator,
            configuration: configuration,
            domainResolutionService: domainResolutionService,
            tokensService: tokensService)

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
    private let domainResolutionService: DomainNameResolutionServiceType
    private var canBeDismissed = true
    private var server: RPCServer { configurator.session.server }
    private let navigationController: UIViewController
    private let keystore: Keystore
    private let tokensService: TokensProcessingPipeline
    private var cancellable = Set<AnyCancellable>()

    var coordinators: [Coordinator] = []
    weak var delegate: TransactionConfirmationCoordinatorDelegate?

    init(presentingViewController: UIViewController,
         session: WalletSession,
         transaction: UnconfirmedTransaction,
         configuration: TransactionType.Configuration,
         analytics: AnalyticsLogger,
         domainResolutionService: DomainNameResolutionServiceType,
         keystore: Keystore,
         tokensService: TokensProcessingPipeline,
         networkService: NetworkService) {

        configurator = TransactionConfigurator(
            session: session,
            transaction: transaction,
            networkService: networkService,
            tokensService: tokensService,
            configuration: configuration)

        self.keystore = keystore
        self.configuration = configuration
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
        self.navigationController = presentingViewController
        self.tokensService = tokensService
    }

    func start(fromSource source: Analytics.TransactionConfirmationSource) {
        let presenter = UIApplication.shared.presentedViewController(or: navigationController)
        presenter.present(hostViewController, animated: true)

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
        switch error.type {
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
        case .unknown:
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

        Task { @MainActor in
            do {
                let result = try await sendTransaction()
                handleSendTransactionSuccessfully(result: result)
                logCompleteActionSheetForTransactionConfirmationSuccessfully()
            } catch {
                logActionSheetForTransactionConfirmationFailed()
                //TODO remove delay which is currently needed because the starting animation may not have completed and internal state (whether animation is running) is in correct
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.rootViewController.set(state: .done(withError: true)) {
                        self.handleSendTransactionError(error)
                    }
                }
            }

            sender.isEnabled = true
            self.canBeDismissed = true
        }.store(in: &cancellable)
    }

    private func sendTransaction() async throws -> ConfirmResult {
        let prompt = R.string.localizable.keystoreAccessKeySign()
        let sender = SendTransaction(session: configurator.session, keystore: keystore, confirmType: configuration.confirmType, config: configurator.session.config, analytics: analytics, prompt: prompt)
        let transaction = configurator.formUnsignedTransaction()
        infoLog("[TransactionConfirmation] form unsigned transaction: \(transaction)")
        if configurator.session.config.development.shouldNotSendTransactions {
            throw DevelopmentForcedError(message: "Did not send transaction because of development flag")
        } else {
            return try await sender.send(transaction: transaction)
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
        case let e as SendTransactionNotRetryableError where !server.isTestnet:
            let errorViewController = SendTransactionErrorViewController(analytics: analytics, viewModel: .init(server: server, error: e))
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

    private func showConfigureTransactionViewController(_ configurator: TransactionConfigurator,
                                                        recoveryMode: EditTransactionViewModel.RecoveryMode = .none) {
        let viewModel = ConfigureTransactionViewModel(
            configurator: configurator,
            recoveryMode: recoveryMode,
            service: tokensService)

        let controller = ConfigureTransactionViewController(viewModel: viewModel)
        controller.delegate = self

        let navigationController = NavigationController(rootViewController: controller)
        navigationController.makePresentationFullScreenForiOS13Migration()
        controller.navigationItem.rightBarButtonItem = .closeBarButton(self, selector: #selector(configureTransactionDidDismiss))

        hostViewController.present(navigationController, animated: true)

        configureTransactionViewController = controller
    }

    @objc func configureTransactionDidDismiss() {
        configureTransactionViewController?.navigationController?.dismiss(animated: true)
    }
}

extension TransactionConfirmationCoordinator: ConfigureTransactionViewControllerDelegate {

    func didSaved(in viewController: ConfigureTransactionViewController) {
        viewController.navigationController?.dismiss(animated: true)
    }
}

// MARK: Analytics
extension TransactionConfirmationCoordinator {
    private func logCompleteActionSheetForTransactionConfirmationSuccessfully() {
        let speedType: Analytics.TransactionConfirmationSpeedType
        switch configurator.selectedGasSpeed {
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

        let transactionType: Analytics.TransactionType = functional.analyticsTransactionType(fromConfiguration: configuration, data: configurator.data)
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
        case .sendFungiblesTransaction:
            switch configurator.transaction.transactionType.amount {
            case .notSet, .none, .amount:
                analyticsProperties[Analytics.Properties.isAllFunds.rawValue] = false
            case .allFunds:
                analyticsProperties[Analytics.Properties.isAllFunds.rawValue] = true
            }
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
        analytics.log(navigation: Analytics.Navigation.actionSheetForTransactionConfirmationFailed, properties: [Analytics.Properties.chain.rawValue: server.chainID])
    }

    private func logStartActionSheetForTransactionConfirmation(source: Analytics.TransactionConfirmationSource) {
        let transactionType: Analytics.TransactionType = functional.analyticsTransactionType(fromConfiguration: configuration, data: configurator.data)
        var analyticsProperties: [String: AnalyticsEventPropertyValue] = [
            Analytics.Properties.source.rawValue: source.rawValue,
            Analytics.Properties.chain.rawValue: server.chainID,
            Analytics.Properties.transactionType.rawValue: transactionType.rawValue,
        ]
        switch configuration {
        case .sendFungiblesTransaction:
            switch configurator.transaction.transactionType.amount {
            case .notSet, .none, .amount:
                analyticsProperties[Analytics.Properties.isAllFunds.rawValue] = false
            case .allFunds:
                analyticsProperties[Analytics.Properties.isAllFunds.rawValue] = true
            }
        case .tokenScriptTransaction, .dappTransaction, .walletConnect, .sendNftTransaction, .claimPaidErc875MagicLink, .speedupTransaction, .cancelTransaction, .swapTransaction, .approve:
            break
        }
        analytics.log(navigation: Analytics.Navigation.actionSheetForTransactionConfirmation, properties: analyticsProperties)
    }
}

extension TransactionConfirmationCoordinator: SendTransactionErrorViewControllerDelegate {
    func rectifyErrorButtonTapped(error: SendTransactionNotRetryableError, in viewController: SendTransactionErrorViewController) {
        viewController.dismiss(animated: true) {
            self.rectifyTransactionError(error: error)
        }
    }

    func linkTapped(_ url: URL, forError error: SendTransactionNotRetryableError, in viewController: SendTransactionErrorViewController) {
        viewController.dismiss(animated: true) {
            self.delegate?.didPressOpenWebPage(url, in: self.rootViewController)
        }
    }

    func didClose(in viewController: SendTransactionErrorViewController) {
        viewController.dismiss(animated: true)
    }
}

extension SendTransactionNotRetryableError {
    var analyticsName: String {
        switch self.type {
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
        case .unknown(_, let message):
            return "unknown error: \(message)"
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
