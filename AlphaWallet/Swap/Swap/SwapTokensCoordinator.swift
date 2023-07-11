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
import AlphaWalletFoundation
import AlphaWalletCore

protocol SwapTokensCoordinatorDelegate: CanOpenURL, BuyCryptoDelegate {
    func didFinish(_ result: ConfirmResult, in coordinator: SwapTokensCoordinator)
    func didCancel(in coordinator: SwapTokensCoordinator)
    func didSendTransaction(_ transaction: SentTransaction, in coordinator: SwapTokensCoordinator)
}

final class SwapTokensCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private lazy var rootViewController: SwapTokensViewController = {
        let viewModel = SwapTokensViewModel(configurator: configurator, tokensPipeline: tokensPipeline)
        let viewController = SwapTokensViewController(viewModel: viewModel, tokenImageFetcher: tokenImageFetcher)
        viewController.navigationItem.rightBarButtonItems = [
            UIBarButtonItem.settingsBarButton(self, selector: #selector(swapConfiguratinSelected)),
            UIBarButtonItem(customView: viewController.loadingIndicatorView)
        ]
        viewController.delegate = self

        return viewController
    }()
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokensPipeline: TokensProcessingPipeline
    private let configurator: SwapOptionsConfigurator
    private lazy var tokenSelectionProvider = SwapTokenSelectionProvider(configurator: configurator)
    private lazy var approveSwapProvider: ApproveSwapProvider = {
        let provider = ApproveSwapProvider(
            configurator: configurator,
            analytics: analytics,
            transactionDataStore: transactionDataStore)

        provider.delegate = self
        return provider
    }()
    private let keystore: Keystore
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainNameResolutionServiceType
    private var transactionConfirmationResult: ConfirmResult? = .none
    private let tokensFilter: TokensFilter
    private let networkService: NetworkService
    private let transactionDataStore: TransactionDataStore
    private let tokenImageFetcher: TokenImageFetcher
    private let tokensService: TokensService

    var coordinators: [Coordinator] = []
    weak var delegate: SwapTokensCoordinatorDelegate?

    init(navigationController: UINavigationController,
         configurator: SwapOptionsConfigurator,
         keystore: Keystore,
         analytics: AnalyticsLogger,
         domainResolutionService: DomainNameResolutionServiceType,
         assetDefinitionStore: AssetDefinitionStore,
         tokensPipeline: TokensProcessingPipeline,
         tokensFilter: TokensFilter,
         networkService: NetworkService,
         transactionDataStore: TransactionDataStore,
         tokenImageFetcher: TokenImageFetcher,
         tokensService: TokensService) {

        self.tokensService = tokensService
        self.tokenImageFetcher = tokenImageFetcher
        self.transactionDataStore = transactionDataStore
        self.networkService = networkService
        self.tokensFilter = tokensFilter
        self.assetDefinitionStore = assetDefinitionStore
        self.tokensPipeline = tokensPipeline
        self.configurator = configurator
        self.navigationController = navigationController
        self.keystore = keystore
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
    }

    func start() {
        configurator.start()
        navigationController.pushViewController(rootViewController, animated: true)
    }

    @objc private func swapConfiguratinSelected(_ sender: UIBarButtonItem) {
        let coordinator = SwapOptionsCoordinator(
            navigationController: navigationController,
            configurator: configurator)

        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }

    private func showSelectToken() {
        let coordinator = SelectTokenCoordinator(
            tokensPipeline: tokensPipeline,
            tokensFilter: tokensFilter,
            navigationController: navigationController,
            filter: .filter(tokenSelectionProvider),
            tokenImageFetcher: tokenImageFetcher,
            tokensService: tokensService)

        coordinator.rootViewController.navigationItem.leftBarButtonItem = UIBarButtonItem.logoBarButton()
        coordinator.delegate = self
        addCoordinator(coordinator)

        let panel = FloatingPanelController(isPanEnabled: false)
        panel.layout = FullScreenScrollableFloatingPanelLayout()
        panel.set(contentViewController: coordinator.navigationController)
        panel.surfaceView.contentPadding = .init(top: 20, left: 0, bottom: 0, right: 0)
        panel.shouldDismissOnBackdrop = true
        panel.delegate = self

        self.navigationController.present(panel, animated: true)
    }
}

extension SwapTokensCoordinator: FloatingPanelControllerDelegate {

    func floatingPanelDidRemove(_ fpc: FloatingPanelController) {
        guard let coordinator = coordinators.compactMap({ $0 as? SelectTokenCoordinator }).first else { return }

        removeCoordinator(coordinator)
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
    func changeSwapRouteSelected(in viewController: SwapTokensViewController) {
        let viewModel = SelectSwapRouteViewModel(storage: configurator.tokenSwapper.storage)
        let viewController = SelectSwapRouteViewController(viewModel: viewModel)

        navigationController.pushViewController(viewController, animated: true)
    }

    func chooseTokenSelected(in viewController: SwapTokensViewController, selection: SwapTokens.TokenSelection) {
        tokenSelectionProvider.set(pendingTokenSelection: selection)
        showSelectToken()
    }

    func swapSelected(in viewController: SwapTokensViewController) {
        guard let swapQuote = configurator.lastSwapQuote, let fromAmount = configurator.fromAmount else {
            showError(SwapError.tokenOrSwapQuoteNotFound)
            return
        }

        approveSwapProvider.approveSwap(swapQuote: swapQuote, fromAmount: fromAmount)
    }

    func didClose(in viewController: SwapTokensViewController) {
        removeAllCoordinators()

        delegate?.didCancel(in: self)
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

    func didFailure(in approveSwapProvider: ApproveSwapProvider, error: SwapError) {
        rootViewController.hideLoading()

        switch error {
        case .unableToBuildSwapUnsignedTransaction, .unableToBuildSwapUnsignedTransactionFromSwapProvider, .userCancelledApproval, .tokenOrSwapQuoteNotFound:
            return
        case .unknownError, .inner, .invalidJson:
            break
        }

        if error.isUserCancelledError {
            //no-op
        } else {
            UIApplication.shared
                .presentedViewController(or: navigationController)
                .displayError(message: error.localizedDescription)
        }
    }

    func promptToSwap(unsignedTransaction: UnsignedSwapTransaction, fromToken: TokenToSwap, fromAmount: BigUInt, toToken: TokenToSwap, toAmount: BigUInt, in provider: ApproveSwapProvider) {

        let (transaction, configuration) = configurator.tokenSwapper.buildSwapTransaction(
            unsignedTransaction: unsignedTransaction,
            fromToken: fromToken,
            fromAmount: fromAmount,
            toToken: toToken,
            toAmount: toAmount)

        let coordinator = TransactionConfirmationCoordinator(
            presentingViewController: navigationController,
            session: configurator.session,
            transaction: transaction,
            configuration: configuration,
            analytics: analytics,
            domainResolutionService: domainResolutionService,
            keystore: keystore,
            tokensService: tokensPipeline,
            networkService: networkService)

        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start(fromSource: .swap)
    }

    func promptForErc20Approval(token: AlphaWallet.Address, server: RPCServer, owner: AlphaWallet.Address, spender: AlphaWallet.Address, amount: BigUInt, in provider: ApproveSwapProvider) -> AnyPublisher<String, PromiseError> {
        return firstly {
            Promise.value(token)
        }.map { contract in
            try UnconfirmedTransaction.buildApproveTransaction(
                contract: contract,
                server: server,
                owner: owner,
                spender: spender,
                amount: amount)
        }.then { [navigationController, keystore, analytics, configurator, tokensPipeline, domainResolutionService, networkService] (transaction, configuration) in
            TransactionConfirmationCoordinator.promise(
                navigationController,
                session: configurator.session,
                coordinator: self,
                transaction: transaction,
                configuration: configuration,
                analytics: analytics,
                domainResolutionService: domainResolutionService,
                source: .swapApproval,
                delegate: self,
                keystore: keystore,
                tokensService: tokensPipeline,
                networkService: networkService)
        }.map { confirmationResult in
            switch confirmationResult {
            case .signedTransaction, .sentRawTransaction:
                throw SwapError.unknownError
            case .sentTransaction(let transaction):
                return transaction.id
            }
        }.recover { error -> Promise<String> in
            //TODO no good to have `JsonRpcError` here, but this is because of `TransactionConfirmationCoordinatorBridgeToPromise`. Maybe good to have a global "UserCancelled" or something? If enum, not too many cases? To avoid `switch`
            if let e = error as? JsonRpcError, e == .requestRejected {
                throw SwapError.userCancelledApproval
            } else {
                throw error
            }
        }.publisher()
    }

    private func showError(_ error: Error) {
        UIApplication.shared
            .presentedViewController(or: navigationController)
            .displayError(message: error.localizedDescription)
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

            let coordinator = TransactionInProgressCoordinator(
                presentingViewController: strongSelf.navigationController,
                server: strongSelf.configurator.server)

            coordinator.delegate = strongSelf
            strongSelf.addCoordinator(coordinator)

            coordinator.start()
        }
    }

    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: Error) {
        UIApplication.shared
            .presentedViewController(or: navigationController)
            .displayError(message: error.localizedDescription)
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

extension SwapTokensCoordinator: BuyCryptoDelegate {
    func buyCrypto(wallet: Wallet, server: RPCServer, viewController: UIViewController, source: Analytics.BuyCryptoSource) {
        delegate?.buyCrypto(wallet: wallet, server: server, viewController: viewController, source: .transactionActionSheetInsufficientFunds)
    }
}
import AlphaWalletAddress
public extension UnconfirmedTransaction {
    static func buildApproveTransaction(contract: AlphaWallet.Address, server: RPCServer, owner: AlphaWallet.Address, spender: AlphaWallet.Address, amount: BigUInt) throws -> (UnconfirmedTransaction, TransactionType.Configuration) {
        let configuration: TransactionType.Configuration = .approve
        let transactionType: TransactionType = .prebuilt(server)
        let data = (try? Erc20Approve(spender: spender, value: amount).encodedABI()) ?? Data()

        let transaction = UnconfirmedTransaction(
            transactionType: transactionType,
            value: 0,
            recipient: nil,
            contract: contract,
            data: data)

        return (transaction, configuration)
    }
}
