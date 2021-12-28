// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import PromiseKit

protocol TokensCoordinatorDelegate: CanOpenURL, SendTransactionDelegate {
    func didTapSwap(forTransactionType transactionType: TransactionType, service: SwapTokenURLProviderType, in coordinator: TokensCoordinator)
    func shouldOpen(url: URL, shouldSwitchServer: Bool, forTransactionType transactionType: TransactionType, in coordinator: TokensCoordinator)
    func didPress(for type: PaymentFlow, server: RPCServer, inViewController viewController: UIViewController?, in coordinator: TokensCoordinator)
    func didTap(transaction: TransactionInstance, inViewController viewController: UIViewController, in coordinator: TokensCoordinator)
    func didTap(activity: Activity, inViewController viewController: UIViewController, in coordinator: TokensCoordinator)
    func openConsole(inCoordinator coordinator: TokensCoordinator)
    func didPostTokenScriptTransaction(_ transaction: SentTransaction, in coordinator: TokensCoordinator)
    func blockieSelected(in coordinator: TokensCoordinator)
    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TokensCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource)

    func whereAreMyTokensSelected(in coordinator: TokensCoordinator)
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
    //NOTE: private (set) - `For test purposes only`
    private (set) lazy var tokensViewController: TokensViewController = {
        let controller = TokensViewController(
            sessions: sessions,
            account: sessions.anyValue.account,
            tokenCollection: tokenCollection,
            assetDefinitionStore: assetDefinitionStore,
            eventsDataStore: eventsDataStore,
            filterTokensCoordinator: filterTokensCoordinator,
            config: config,
            walletConnectCoordinator: walletConnectCoordinator,
            walletBalanceCoordinator: walletBalanceCoordinator,
            analyticsCoordinator: analyticsCoordinator
        )
        controller.delegate = self
        return controller
    }()

    private var addressToAutoDetectServerFor: AlphaWallet.Address?
    private var sendToAddress: AlphaWallet.Address? = .none
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
    private let walletBalanceCoordinator: WalletBalanceCoordinatorType
    private lazy var alertService: PriceAlertServiceType = {
        PriceAlertService(datastore: PriceAlertDataStore(wallet: sessions.anyValue.account), wallet: sessions.anyValue.account)
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
            activitiesService: ActivitiesServiceType,
            walletBalanceCoordinator: WalletBalanceCoordinatorType
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
        self.walletBalanceCoordinator = walletBalanceCoordinator
        promptBackupCoordinator.prominentPromptDelegate = self
        setupSingleChainTokenCoordinators()

        let moreBarButton = UIBarButtonItem.moreBarButton(self, selector: #selector(moreButtonSelected))
        let qrCodeBarButton = UIBarButtonItem.qrCodeBarButton(self, selector: #selector(scanQRCodeButtonSelected))
        moreBarButton.imageInsets = .init(top: 0, left: 0, bottom: 0, right: 0)
        qrCodeBarButton.imageInsets = .init(top: 0, left: 15, bottom: 0, right: -15)

        tokensViewController.navigationItem.rightBarButtonItems = [
            moreBarButton,
            qrCodeBarButton
        ]
        tokensViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: tokensViewController.blockieImageView)
        tokensViewController.blockieImageView.addTarget(self, action: #selector(blockieButtonSelected), for: .touchUpInside)
    }

    @objc private func blockieButtonSelected(_ sender: UIButton) {
        delegate?.blockieSelected(in: self)
    }

    @objc private func scanQRCodeButtonSelected(_ sender: UIBarButtonItem) {
        if config.shouldReadClipboardForWalletConnectUrl {
            if let s = UIPasteboard.general.string ?? UIPasteboard.general.url?.absoluteString, let url = WalletConnectURL(s) {
                walletConnectCoordinator.openSession(url: url)
            }
        } else {
            launchUniversalScanner(fromSource: .walletScreen)
        }
    }

    @objc private func moreButtonSelected(_ sender: UIBarButtonItem) {
        let alertViewController = makeMoreAlertSheet(sender: sender)
        tokensViewController.present(alertViewController, animated: true)
    }

    func start() {
        for each in singleChainTokenCoordinators {
            each.start()
        }
        addUefaTokenIfAny()
        showTokens()
        alertService.start()
    }

    private func setupSingleChainTokenCoordinators() {
        for each in tokenCollection.tokenDataStores {
            let server = each.server
            let session = sessions[server]
            let price = nativeCryptoCurrencyPrices[server]
            let transactionsStorage = transactionsStorages[server]
            let coordinator = SingleChainTokenCoordinator(session: session, keystore: keystore, tokensStorage: each, ethPrice: price, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, analyticsCoordinator: analyticsCoordinator, withAutoDetectTransactedTokensQueue: autoDetectTransactedTokensQueue, withAutoDetectTokensQueue: autoDetectTokensQueue, tokenActionsProvider: tokenActionsService, transactionsStorage: transactionsStorage, coinTickersFetcher: coinTickersFetcher, activitiesService: activitiesService, alertService: alertService)
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

    private func addUefaTokenIfAny() {
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

    func whereAreMyTokensSelected(in viewController: UIViewController) {
        delegate?.whereAreMyTokensSelected(in: self)
    }
    
    private func getWalletName() {
        let viewModel = tokensViewController.viewModel

        tokensViewController.title = viewModel.walletDefaultTitle

        firstly {
            GetWalletNameCoordinator(config: config).getName(forAddress: sessions.anyValue.account.address)
        }.done { [weak self] name in
            self?.tokensViewController.navigationItem.title = name ?? viewModel.walletDefaultTitle
        }.cauterize()
    }

    private func getWalletBlockie() {
        let generator = BlockiesGenerator()
        generator.promise(address: sessions.anyValue.account.address).done { [weak self] value in
            self?.tokensViewController.blockieImageView.image = value
        }.catch { [weak self] _ in
            self?.tokensViewController.blockieImageView.image = nil
        }
    }

    func viewWillAppear(in viewController: UIViewController) {
        getWalletName()
        getWalletBlockie()
    }

    private func makeMoreAlertSheet(sender: UIBarButtonItem) -> UIAlertController {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.popoverPresentationController?.barButtonItem = sender

        let copyAddressAction = UIAlertAction(title: R.string.localizable.copyAddress(), style: .default) { [weak self] _ in
            guard let strongSelf = self else { return }
            UIPasteboard.general.string = strongSelf.sessions.anyValue.account.address.eip55String
            strongSelf.tokensViewController.view.showCopiedToClipboard(title: R.string.localizable.copiedToClipboard())
        }
        alertController.addAction(copyAddressAction)

        let showMyWalletAddressAction = UIAlertAction(title: R.string.localizable.settingsShowMyWalletTitle(), style: .default) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.didPress(for: .request, server: strongSelf.config.anyEnabledServer(), inViewController: .none, in: strongSelf)
        }
        alertController.addAction(showMyWalletAddressAction)

        if config.enabledServers.contains(.main) {
            let buyAction = UIAlertAction(title: R.string.localizable.buyCryptoTitle(), style: .default) { [weak self] _ in
                guard let strongSelf = self else { return }
                let server = RPCServer.main
                let account = strongSelf.sessions.anyValue.account
                strongSelf.delegate?.openFiatOnRamp(wallet: account, server: server, inCoordinator: strongSelf, viewController: strongSelf.tokensViewController, source: .walletTab)
            }
            alertController.addAction(buyAction)
        }

        let addHideTokensAction = UIAlertAction(title: R.string.localizable.walletsAddHideTokensTitle(), style: .default) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.didPressAddHideTokens(viewModel: strongSelf.rootViewController.viewModel)
        }
        alertController.addAction(addHideTokensAction)

        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in }
        alertController.addAction(cancelAction)

        return alertController
    }

    func walletConnectSelected(in viewController: UIViewController) {
        walletConnectCoordinator.showSessionDetails(in: navigationController)
    }

    private func didPressAddHideTokens(viewModel: TokensViewModel) {
        let coordinator: AddHideTokensCoordinator = .init(
            tokens: viewModel.tokens,
            assetDefinitionStore: assetDefinitionStore,
            filterTokensCoordinator: filterTokensCoordinator,
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
            coordinator.show(fungibleToken: token, transactionType: .erc20Token(token, destination: nil, amount: nil), navigationController: navigationController)
        case .erc721:
            coordinator.showTokenList(for: .send(type: .transaction(.erc721Token(token, tokenHolders: []))), token: token, navigationController: navigationController)
        case .erc875, .erc721ForTickets:
            coordinator.showTokenList(for: .send(type: .transaction(.erc875Token(token, tokenHolders: []))), token: token, navigationController: navigationController)
        case .erc1155:
            coordinator.showTokenList(for: .send(type: .transaction(.erc1155Token(token, transferType: .singleTransfer, tokenHolders: []))), token: token, navigationController: navigationController)
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
}

extension TokensCoordinator: SelectTokenCoordinatorDelegate {

    func coordinator(_ coordinator: SelectTokenCoordinator, didSelectToken token: TokenObject) {
        removeCoordinator(coordinator)

        switch sendToAddress {
        case .some(let address):
            let paymentFlow = PaymentFlow.send(type: .transaction(.init(token: token, recipient: .address(address), amount: nil)))

            delegate?.didPress(for: paymentFlow, server: token.server, inViewController: .none, in: self)
        case .none:
            break
        }
        sendToAddress = .none
    }

    func selectAssetDidCancel(in coordinator: SelectTokenCoordinator) {
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

        let paymentFlow = PaymentFlow.send(type: .transaction(transactionType))

        delegate?.didPress(for: paymentFlow, server: token.server, inViewController: .none, in: self)
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
        sendToAddress = address

        let coordinator = SelectTokenCoordinator(
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

extension TokensCoordinator: EditPriceAlertCoordinatorDelegate {
    func didClose(in coordinator: EditPriceAlertCoordinator) {
        removeCoordinator(coordinator)
    }

    func didUpdateAlert(in coordinator: EditPriceAlertCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension TokensCoordinator: SingleChainTokenCoordinatorDelegate {
    
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator) {
        delegate?.didSendTransaction(transaction, inCoordinator: coordinator)
    }

    func didTapAddAlert(for tokenObject: TokenObject, in cordinator: SingleChainTokenCoordinator) {
        let coordinatorToAdd = EditPriceAlertCoordinator(navigationController: navigationController, configuration: .create, tokenObject: tokenObject, session: cordinator.session, alertService: alertService)
        addCoordinator(coordinatorToAdd)
        coordinatorToAdd.delegate = self
        coordinatorToAdd.start()
    }

    func didTapEditAlert(for tokenObject: TokenObject, alert: PriceAlert, in cordinator: SingleChainTokenCoordinator) {
        let coordinatorToAdd = EditPriceAlertCoordinator(navigationController: navigationController, configuration: .edit(alert), tokenObject: tokenObject, session: cordinator.session, alertService: alertService)
        addCoordinator(coordinatorToAdd)
        coordinatorToAdd.delegate = self
        coordinatorToAdd.start()
    }

    func didTapSwap(forTransactionType transactionType: TransactionType, service: SwapTokenURLProviderType, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didTapSwap(forTransactionType: transactionType, service: service, in: self)
    }

    func shouldOpen(url: URL, shouldSwitchServer: Bool, forTransactionType transactionType: TransactionType, in coordinator: SingleChainTokenCoordinator) {
        delegate?.shouldOpen(url: url, shouldSwitchServer: shouldSwitchServer, forTransactionType: transactionType, in: self)
    }

    func tokensDidChange(inCoordinator coordinator: SingleChainTokenCoordinator) {
        tokensViewController.fetch()
    }

    func didPress(for type: PaymentFlow, inViewController viewController: UIViewController, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didPress(for: type, server: coordinator.session.server, inViewController: viewController, in: self)
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

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: SingleChainTokenCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource) {
        delegate?.openFiatOnRamp(wallet: wallet, server: server, inCoordinator: self, viewController: viewController, source: source)
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
