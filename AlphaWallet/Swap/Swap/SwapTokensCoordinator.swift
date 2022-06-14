//
//  SwapTokensCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.03.2022.
//

import UIKit
import Combine
import FloatingPanel
import PromiseKit
import BigInt
import Result

protocol SwapTokensCoordinatorDelegate: class, CanOpenURL {
    func didFinish(_ result: ConfirmResult, in coordinator: SwapTokensCoordinator)
    func didCancel(in coordinator: SwapTokensCoordinator)
    func didSendTransaction(_ transaction: SentTransaction, in coordinator: SwapTokensCoordinator)
    func openFiatOnRamp(wallet: Wallet, server: RPCServer, coordinator: SwapTokensCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource)
}

final class SwapTokensCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private lazy var rootViewController: SwapTokensViewController = {
        let viewModel = SwapTokensViewModel(configurator: configurator)
        let viewController = SwapTokensViewController(viewModel: viewModel)
        viewController.navigationItem.rightBarButtonItems = [
            UIBarButtonItem.settingsBarButton(self, selector: #selector(swapConfiguratinSelected)),
            UIBarButtonItem(customView: viewController.loadingIndicatorView)
        ]
        viewController.navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(self, selector: #selector(cancelSelected))
        viewController.delegate = self

        return viewController
    }()
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokenCollection: TokenCollection
    private let configurator: SwapOptionsConfigurator
    private lazy var tokenSelectionProvider = SwapTokenSelectionProvider(configurator: configurator)
    private lazy var approveSwapProvider: ApproveSwapProvider = {
        let provider = ApproveSwapProvider(configurator: configurator)
        provider.delegate = self
        return provider
    }()
    private let keystore: Keystore
    private let analyticsCoordinator: AnalyticsCoordinator
    private let domainResolutionService: DomainResolutionServiceType
    private let eventsDataStore: NonActivityEventsDataStore
    private var cancelable = Set<AnyCancellable>()
    private var transactionConfirmationResult: ConfirmResult? = .none

    var coordinators: [Coordinator] = []
    weak var delegate: SwapTokensCoordinatorDelegate?

    init(navigationController: UINavigationController, configurator: SwapOptionsConfigurator, keystore: Keystore, analyticsCoordinator: AnalyticsCoordinator, domainResolutionService: DomainResolutionServiceType, assetDefinitionStore: AssetDefinitionStore, tokenCollection: TokenCollection, eventsDataStore: NonActivityEventsDataStore) {
        self.assetDefinitionStore = assetDefinitionStore
        self.tokenCollection = tokenCollection
        self.configurator = configurator
        self.navigationController = navigationController
        self.keystore = keystore
        self.analyticsCoordinator = analyticsCoordinator
        self.domainResolutionService = domainResolutionService
        self.eventsDataStore = eventsDataStore
    }

    func start() {
        configurator.start()
        navigationController.pushViewController(rootViewController, animated: true)
    }

    @objc private func cancelSelected(_ sender: UIBarButtonItem) {
        removeAllCoordinators()

        delegate?.didCancel(in: self)
    }

    @objc private func swapConfiguratinSelected(_ sender: UIBarButtonItem) {
        let coordinator = SwapOptionsCoordinator(navigationController: navigationController, configurator: configurator)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }

    private func showSelectToken() {
        let coordinator = SelectTokenCoordinator(assetDefinitionStore: assetDefinitionStore, wallet: configurator.session.account, tokenBalanceService: configurator.session.tokenBalanceService, tokenCollection: tokenCollection, navigationController: navigationController, filter: .filter(tokenSelectionProvider), eventsDataStore: eventsDataStore)
        coordinator.configureForSelectionSwapToken()
        coordinator.delegate = self
        addCoordinator(coordinator)

        let panel = FloatingPanelController(isPanEnabled: false)
        panel.layout = FullScreenScrollableFloatingPanelLayout()
        panel.set(contentViewController: coordinator.rootViewController)
        panel.shouldDismissOnBackdrop = true
        panel.delegate = self

        navigationController.present(panel, animated: true)
    }
}

extension SwapTokensCoordinator: FloatingPanelControllerDelegate {

    func floatingPanelDidRemove(_ fpc: FloatingPanelController) {
        guard let coordinator = coordinators.compactMap({ $0 as? SelectTokenCoordinator }).first else { return }
        coordinator.close()
    }
}

extension SwapTokensCoordinator: SwapOptionsCoordinatorDelegate {

    func didClose(in coordinator: SwapOptionsCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension SwapTokensCoordinator: SelectTokenCoordinatorDelegate {

    func coordinator(_ coordinator: SelectTokenCoordinator, didSelectToken token: Token) {
        removeCoordinator(coordinator)

        guard let selection = tokenSelectionProvider.pendingTokenSelection else { return }
        configurator.set(token: token, selection: selection)
        tokenSelectionProvider.resetPendingTokenSelection()
    }

    func didCancel(in coordinator: SelectTokenCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension SwapTokensCoordinator: SwapTokensViewControllerDelegate {
    func chooseTokenSelected(in viewController: SwapTokensViewController, selection: SwapTokens.TokenSelection) {
        tokenSelectionProvider.set(pendingTokenSelection: selection)
        showSelectToken()
    }

    func swapSelected(in viewController: SwapTokensViewController) {
        guard let value = configurator.lastTokensWithTheirSwapQuote, let fromAmount = configurator.fromAmount else {
            showError(SwapError.tokenOrSwapQuoteNotFound)
            return
        }

        approveSwapProvider.approveSwap(value: value, fromAmount: fromAmount)
    }
}

extension SwapTokensCoordinator: ApproveSwapProviderDelegate {
    func changeState(in approveSwapProvider: ApproveSwapProvider, state: ApproveSwapState) {
        switch state {
        case .pending, .waitingForUsersAllowanceApprove, .waitingForUsersSwapApprove:
            rootViewController.hideLoading()
        case .checkingForEnoughAllowance, .waitTillApproveCompleted:
            rootViewController.displayLoading()
        }
    }

    func didFailure(in approveSwapProvider: ApproveSwapProvider, error: Error) {
        rootViewController.hideLoading()

        if error.isUserCancelledError {
            //no-op
        } else {
            UIApplication.shared
                .presentedViewController(or: navigationController)
                .displayError(message: error.prettyError)
        }
    }

    func promptToSwap(unsignedTransaction: UnsignedSwapTransaction, fromToken: TokenToSwap, fromAmount: BigUInt, toToken: TokenToSwap, toAmount: BigUInt, in provider: ApproveSwapProvider) {
        let (transaction, configuration) = configurator.tokenSwapper.buildSwapTransaction(keystore: keystore, unsignedTransaction: unsignedTransaction, fromToken: fromToken, fromAmount: fromAmount, toToken: toToken, toAmount: toAmount)
        let coordinator = TransactionConfirmationCoordinator(presentingViewController: navigationController, session: configurator.session, transaction: transaction, configuration: configuration, analyticsCoordinator: analyticsCoordinator, domainResolutionService: domainResolutionService)
        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start(fromSource: .swap)
    }

    func promptForErc20Approval(token: AlphaWallet.Address, server: RPCServer, owner: AlphaWallet.Address, spender: AlphaWallet.Address, amount: BigUInt, in provider: ApproveSwapProvider) -> Promise<EthereumTransaction.Id> {
        let (transaction, configuration) = Erc20.buildApproveTransaction(keystore: keystore, token: token, server: server, owner: owner, spender: spender, amount: amount)

        return firstly {
            TransactionConfirmationCoordinator.promise(navigationController, session: configurator.session, coordinator: self, transaction: transaction, configuration: configuration, analyticsCoordinator: analyticsCoordinator, domainResolutionService: domainResolutionService, source: .swapApproval, delegate: self)
        }.map { confirmationResult in
            switch confirmationResult {
            case .signedTransaction, .sentRawTransaction:
                throw SwapError.unknownError
            case .sentTransaction(let transaction):
                return transaction.id
            }
        }.recover { error -> Promise<EthereumTransaction.Id> in
            //TODO no good to have `DAppError` here, but this is because of `TransactionConfirmationCoordinatorBridgeToPromise`. Maybe good to have a global "UserCancelled" or something? If enum, not too many cases? To avoid `switch`
            if case DAppError.cancelled = error {
                throw SwapError.userCancelledApproval
            } else {
                throw error
            }
        }
    }

    private func showError(_ error: Error) {
        UIApplication.shared
            .presentedViewController(or: navigationController)
            .displayError(message: error.prettyError)
    }
}

extension SwapTokensCoordinator: TransactionInProgressCoordinatorDelegate {
    func didDismiss(in coordinator: TransactionInProgressCoordinator) {
        removeCoordinator(coordinator)

        guard case .some(let result) = transactionConfirmationResult else { return }
        delegate?.didFinish(result, in: self)
    }
}

extension SwapTokensCoordinator: TransactionConfirmationCoordinatorDelegate {
    func didFinish(_ result: ConfirmResult, in coordinator: TransactionConfirmationCoordinator) {
        coordinator.close { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.removeCoordinator(coordinator)

            strongSelf.transactionConfirmationResult = result

            let coordinator = TransactionInProgressCoordinator(presentingViewController: strongSelf.navigationController)
            coordinator.delegate = strongSelf
            strongSelf.addCoordinator(coordinator)

            coordinator.start()
        }
    }

    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: AnyError) {
        UIApplication.shared
            .presentedViewController(or: navigationController)
            .displayError(message: error.prettyError)
    }

    func didClose(in coordinator: TransactionConfirmationCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension SwapTokensCoordinator: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}

extension SwapTokensCoordinator: SendTransactionDelegate {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator) {
        delegate?.didSendTransaction(transaction, in: self)
    }
}

extension SwapTokensCoordinator: FiatOnRampDelegate {
    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TransactionConfirmationCoordinator, viewController: UIViewController) {
        delegate?.openFiatOnRamp(wallet: wallet, server: server, coordinator: self, viewController: viewController, source: .transactionActionSheetInsufficientFunds)
    }
}

extension SwapTokensCoordinator {
    enum functional {}
}

fileprivate extension SwapTokensCoordinator.functional {
    static func isTransactionErc20Approval(_ transaction: SentTransaction) -> Bool {
        let data = transaction.original.data
        if let function = DecodedFunctionCall(data: data) {
            switch function.type {
            case .erc1155SafeTransfer, .erc1155SafeBatchTransfer, .erc20Transfer, .nativeCryptoTransfer, .others:
                return false
            case .erc20Approve:
                return true
            }
        } else if data.isEmpty {
            return false
        } else {
            return false
        }
    }
}

extension Error {
    var isUserCancelledError: Bool {
        guard let swapError = self as? SwapError else { return false }
        return SwapError.userCancelledApproval == swapError
    }
}
