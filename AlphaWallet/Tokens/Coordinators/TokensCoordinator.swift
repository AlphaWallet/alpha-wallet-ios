// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import PromiseKit

protocol TokensCoordinatorDelegate: class, CanOpenURL {
    func didTapSwap(forTransactionType transactionType: TransactionType, service: SwapTokenURLProviderType, in coordinator: TokensCoordinator)
    func shouldOpen(url: URL, shouldSwitchServer: Bool, forTransactionType transactionType: TransactionType, in coordinator: TokensCoordinator)
    func didPress(for type: PaymentFlow, server: RPCServer, in coordinator: TokensCoordinator)
    func didTap(transaction: TransactionInstance, inViewController viewController: UIViewController, in coordinator: TokensCoordinator)
    func didTap(activity: Activity, inViewController viewController: UIViewController, in coordinator: TokensCoordinator)
    func openConsole(inCoordinator coordinator: TokensCoordinator)
    func didPostTokenScriptTransaction(_ transaction: SentTransaction, in coordinator: TokensCoordinator)
    func blockieSelected(in coordinator: TokensCoordinator)
}

private struct NoContractDetailsDetected: Error {
}

class TokensCoordinator: Coordinator {
    private let sessions: ServerDictionary<WalletSession>
    private let keystore: Keystore
    private let config: Config
    private let tokenCollection: TokenCollection
    private let nativeCryptoCurrencyPrices: ServerDictionary<Subscribable<Double>>
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: EventsDataStoreProtocol
    private let promptBackupCoordinator: PromptBackupCoordinator
    private let filterTokensCoordinator: FilterTokensCoordinator
    private let analyticsCoordinator: AnalyticsCoordinator
    private let tokenActionsService: TokenActionsServiceType
    private var serverToAddCustomTokenOn: RPCServerOrAuto = .auto {
        didSet {
            switch serverToAddCustomTokenOn {
            case .auto:
                break
            case .server:
                addressToAutoDetectServerFor = nil
            }
        }
    }
    private let autoDetectTransactedTokensQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Auto-detect Transacted Tokens"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private let autoDetectTokensQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Auto-detect Tokens"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private let activitiesService: ActivitiesServiceType
    private lazy var tokensViewController: TokensViewController = {
        let controller = TokensViewController(
            sessions: sessions,
            account: sessions.anyValue.account,
            tokenCollection: tokenCollection,
            assetDefinitionStore: assetDefinitionStore,
            eventsDataStore: eventsDataStore,
            filterTokensCoordinator: filterTokensCoordinator,
            config: config,
            walletConnectCoordinator: walletConnectCoordinator
        )
        controller.delegate = self
        return controller
    }()

    private var addressToAutoDetectServerFor: AlphaWallet.Address?
    private var sendToAddressState: SendToAddressState = .none
    private var singleChainTokenCoordinators: [SingleChainTokenCoordinator] {
        return coordinators.compactMap { $0 as? SingleChainTokenCoordinator }
    }
    private let walletConnectCoordinator: WalletConnectCoordinator
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: TokensCoordinatorDelegate?
    private let transactionsStorages: ServerDictionary<TransactionsStorage>
    private let coinTickersFetcher: CoinTickersFetcherType
    lazy var rootViewController: TokensViewController = {
        return tokensViewController
    }()

    init(
            navigationController: UINavigationController = UINavigationController(),
            sessions: ServerDictionary<WalletSession>,
            keystore: Keystore,
            config: Config,
            tokenCollection: TokenCollection,
            nativeCryptoCurrencyPrices: ServerDictionary<Subscribable<Double>>,
            assetDefinitionStore: AssetDefinitionStore,
            eventsDataStore: EventsDataStoreProtocol,
            promptBackupCoordinator: PromptBackupCoordinator,
            filterTokensCoordinator: FilterTokensCoordinator,
            analyticsCoordinator: AnalyticsCoordinator,
            tokenActionsService: TokenActionsServiceType,
            walletConnectCoordinator: WalletConnectCoordinator,
            transactionsStorages: ServerDictionary<TransactionsStorage>,
            coinTickersFetcher: CoinTickersFetcherType,
            activitiesService: ActivitiesServiceType
    ) {
        self.filterTokensCoordinator = filterTokensCoordinator
        self.navigationController = navigationController
        self.navigationController.modalPresentationStyle = .formSheet
        self.sessions = sessions
        self.keystore = keystore
        self.config = config
        self.tokenCollection = tokenCollection
        self.nativeCryptoCurrencyPrices = nativeCryptoCurrencyPrices
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.promptBackupCoordinator = promptBackupCoordinator
        self.analyticsCoordinator = analyticsCoordinator
        self.tokenActionsService = tokenActionsService
        self.walletConnectCoordinator = walletConnectCoordinator
        self.transactionsStorages = transactionsStorages
        self.coinTickersFetcher = coinTickersFetcher
        self.activitiesService = activitiesService
        promptBackupCoordinator.prominentPromptDelegate = self
        setupSingleChainTokenCoordinators()
    }

    func start() {
        for each in singleChainTokenCoordinators {
            each.start()
        }
        addUefaTokenIfAny()
        showTokens()
    }

    private func setupSingleChainTokenCoordinators() {
        for each in tokenCollection.tokenDataStores {
            let server = each.server
            let session = sessions[server]
            let price = nativeCryptoCurrencyPrices[server]
            let transactionsStorage = transactionsStorages[server]
            let coordinator = SingleChainTokenCoordinator(session: session, keystore: keystore, tokensStorage: each, ethPrice: price, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, analyticsCoordinator: analyticsCoordinator, withAutoDetectTransactedTokensQueue: autoDetectTransactedTokensQueue, withAutoDetectTokensQueue: autoDetectTokensQueue, tokenActionsProvider: tokenActionsService, transactionsStorage: transactionsStorage, coinTickersFetcher: coinTickersFetcher, activitiesService: activitiesService, sessions: sessions)
            coordinator.delegate = self
            addCoordinator(coordinator)
        }
    }

    private func showTokens() {
        navigationController.viewControllers = [rootViewController]
    }

    func addImportedToken(forContract contract: AlphaWallet.Address, server: RPCServer) {
        guard let coordinator = singleChainTokenCoordinator(forServer: server) else { return }
        coordinator.addImportedToken(forContract: contract)
    }

    func addUefaTokenIfAny() {
        let server = Constants.uefaRpcServer
        guard let coordinator = singleChainTokenCoordinator(forServer: server) else { return }
        coordinator.addImportedToken(forContract: Constants.uefaMainnet, onlyIfThereIsABalance: true)
    }

    private func singleChainTokenCoordinator(forServer server: RPCServer) -> SingleChainTokenCoordinator? {
        return singleChainTokenCoordinators.first { $0.isServer(server) }
    }

    func listOfBadTokenScriptFilesChanged(fileNames: [TokenScriptFileIndices.FileName]) {
        tokensViewController.listOfBadTokenScriptFiles = fileNames
    }

    func launchUniversalScanner(fromSource source: Analytics.ScanQRCodeSource) {
        let account = sessions.anyValue.account
        let scanQRCodeCoordinator = ScanQRCodeCoordinator(analyticsCoordinator: analyticsCoordinator, navigationController: navigationController, account: account)
        let tokensDatastores = tokenCollection.tokenDataStores

        let coordinator = QRCodeResolutionCoordinator(config: config, coordinator: scanQRCodeCoordinator, usage: .all(tokensDatastores: tokensDatastores, assetDefinitionStore: assetDefinitionStore))
        coordinator.delegate = self

        addCoordinator(coordinator)
        coordinator.start(fromSource: source)
    }
}

extension TokensCoordinator: TokensViewControllerDelegate {

    func blockieSelected(in viewController: UIViewController) {
        delegate?.blockieSelected(in: self)
    }

    func walletConnectSelected(in viewController: UIViewController) {
        walletConnectCoordinator.showSessionDetails(in: navigationController)
    }

    func didPressAddHideTokens(viewModel: TokensViewModel) {
        let coordinator: AddHideTokensCoordinator = .init(
            tokens: viewModel.tokens,
            assetDefinitionStore: assetDefinitionStore,
            filterTokensCoordinator: filterTokensCoordinator,
            tickers: viewModel.tickers,
            sessions: sessions,
            analyticsCoordinator: analyticsCoordinator,
            navigationController: navigationController,
            tokenCollection: tokenCollection,
            config: config,
            singleChainTokenCoordinators: singleChainTokenCoordinators
        )
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }

    func showSingleChainToken(token: TokenObject, in navigationController: UINavigationController) {
        guard let coordinator = singleChainTokenCoordinator(forServer: token.server) else { return }

        switch token.type {
        case .nativeCryptocurrency:
            coordinator.show(fungibleToken: token, transactionType: .nativeCryptocurrency(token, destination: .none, amount: nil), navigationController: navigationController)
        case .erc20:
            coordinator.show(fungibleToken: token, transactionType: .ERC20Token(token, destination: nil, amount: nil), navigationController: navigationController)
        case .erc721:
            coordinator.showTokenList(for: .send(type: .ERC721Token(token)), token: token, navigationController: navigationController)
        case .erc875, .erc721ForTickets:
            coordinator.showTokenList(for: .send(type: .ERC875Token(token)), token: token, navigationController: navigationController)
        }
    }

    func didSelect(token: TokenObject, in viewController: UIViewController) {
        showSingleChainToken(token: token, in: navigationController)
    }

    func didHide(token: TokenObject, in viewController: UIViewController) {
        guard let coordinator = singleChainTokenCoordinator(forServer: token.server) else { return }
        coordinator.mark(token: token, isHidden: true)
    }

    func didTapOpenConsole(in viewController: UIViewController) {
        delegate?.openConsole(inCoordinator: self)
    }

    func scanQRCodeSelected(in viewController: UIViewController) {
        launchUniversalScanner(fromSource: .walletScreen)
    }
}

extension TokensCoordinator: SelectAssetCoordinatorDelegate {

    func coordinator(_ coordinator: SelectAssetCoordinator, didSelectToken token: TokenObject) {
        removeCoordinator(coordinator)

        switch sendToAddressState {
        case .pending(let address):
            let paymentFlow = PaymentFlow.send(type: .init(token: token, recipient: .address(address), amount: nil))

            delegate?.didPress(for: paymentFlow, server: token.server, in: self)
        case .none:
            break
        }
    }

    func selectAssetDidCancel(in coordinator: SelectAssetCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension TokensCoordinator: QRCodeResolutionCoordinatorDelegate {

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveJSON json: String) {
        removeCoordinator(coordinator)
    }

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveSeedPhase seedPhase: [String]) {
        removeCoordinator(coordinator)
    }

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolvePrivateKey privateKey: String) {
        removeCoordinator(coordinator)
    }

    func didCancel(in coordinator: QRCodeResolutionCoordinator) {
        removeCoordinator(coordinator)
    }

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveTransactionType transactionType: TransactionType, token: TokenObject) {
        removeCoordinator(coordinator)

        let paymentFlow = PaymentFlow.send(type: transactionType)

        delegate?.didPress(for: paymentFlow, server: token.server, in: self)
    }

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveAddress address: AlphaWallet.Address, action: ScanQRCodeAction) {
        removeCoordinator(coordinator)

        switch action {
        case .addCustomToken:
            handleAddCustomToken(address)
        case .sendToAddress:
            handleSendToAddress(address)
        case .watchWallet:
            handleWatchWallet(address)
        case .openInEtherscan:
            delegate?.didPressViewContractWebPage(forContract: address, server: config.anyEnabledServer(), in: tokensViewController)
        }
    }

    private func handleAddCustomToken(_ address: AlphaWallet.Address) {
        let coordinator = NewTokenCoordinator(
            analyticsCoordinator: analyticsCoordinator,
            navigationController: navigationController,
            tokenCollection: tokenCollection,
            config: config,
            singleChainTokenCoordinators: singleChainTokenCoordinators,
            initialState: .address(address),
            sessions: sessions
        )
        coordinator.delegate = self
        addCoordinator(coordinator)

        coordinator.start()
    }

    private enum SendToAddressState {
        case pending(address: AlphaWallet.Address)
        case none
    }

    private func handleSendToAddress(_ address: AlphaWallet.Address) {
        sendToAddressState = .pending(address: address)

        let coordinator = SelectAssetCoordinator(
            assetDefinitionStore: assetDefinitionStore,
            sessions: sessions,
            tokenCollection: tokenCollection,
            navigationController: navigationController,
            filterTokensCoordinator: filterTokensCoordinator
        )
        coordinator.delegate = self
        addCoordinator(coordinator)

        coordinator.start()
    }

    private func handleWatchWallet(_ address: AlphaWallet.Address) {
        let walletCoordinator = WalletCoordinator(config: config, keystore: keystore, analyticsCoordinator: analyticsCoordinator)
        walletCoordinator.delegate = self

        addCoordinator(walletCoordinator)

        walletCoordinator.start(.watchWallet(address: address))
        walletCoordinator.navigationController.makePresentationFullScreenForiOS13Migration()

        navigationController.present(walletCoordinator.navigationController, animated: true)
    }

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveURL url: URL) {
        removeCoordinator(coordinator)

        delegate?.didPressOpenWebPage(url, in: tokensViewController)
    }

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveWalletConnectURL url: WalletConnectURL) {
        removeCoordinator(coordinator)
        walletConnectCoordinator.openSession(url: url)
    }

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveString value: String) {
        removeCoordinator(coordinator)
    }
}

extension TokensCoordinator: NewTokenCoordinatorDelegate {

    func coordinator(_ coordinator: NewTokenCoordinator, didAddToken token: TokenObject) {
        removeCoordinator(coordinator)
    }

    func didClose(in coordinator: NewTokenCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension TokensCoordinator: WalletCoordinatorDelegate {

    func didFinish(with account: Wallet, in coordinator: WalletCoordinator) {
        removeCoordinator(coordinator)

        coordinator.navigationController.dismiss(animated: true)
    }

    func didCancel(in coordinator: WalletCoordinator) {
        removeCoordinator(coordinator)

        coordinator.navigationController.dismiss(animated: true)
    }
}

extension TokensCoordinator: SingleChainTokenCoordinatorDelegate {

    func didTapSwap(forTransactionType transactionType: TransactionType, service: SwapTokenURLProviderType, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didTapSwap(forTransactionType: transactionType, service: service, in: self)
    }

    func shouldOpen(url: URL, shouldSwitchServer: Bool, forTransactionType transactionType: TransactionType, in coordinator: SingleChainTokenCoordinator) {
        delegate?.shouldOpen(url: url, shouldSwitchServer: shouldSwitchServer, forTransactionType: transactionType, in: self)
    }

    func tokensDidChange(inCoordinator coordinator: SingleChainTokenCoordinator) {
        tokensViewController.fetch()
    }

    func didPress(for type: PaymentFlow, inCoordinator coordinator: SingleChainTokenCoordinator) {
        delegate?.didPress(for: type, server: coordinator.session.server, in: self)
    }

    func didTap(activity: Activity, inViewController viewController: UIViewController, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didTap(activity: activity, inViewController: viewController, in: self)
    }

    func didTap(transaction: TransactionInstance, inViewController viewController: UIViewController, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didTap(transaction: transaction, inViewController: viewController, in: self)
    }

    func didPostTokenScriptTransaction(_ transaction: SentTransaction, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didPostTokenScriptTransaction(transaction, in: self)
    }
}

extension TokensCoordinator: CanOpenURL {
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

extension TokensCoordinator: PromptBackupCoordinatorProminentPromptDelegate {
    var viewControllerToShowBackupLaterAlert: UIViewController {
        return tokensViewController
    }

    func updatePrompt(inCoordinator coordinator: PromptBackupCoordinator) {
        tokensViewController.promptBackupWalletView = coordinator.prominentPromptView
    }
}

extension TokensCoordinator: AddHideTokensCoordinatorDelegate {
    func didClose(coordinator: AddHideTokensCoordinator) {
        removeCoordinator(coordinator)
    }
}
