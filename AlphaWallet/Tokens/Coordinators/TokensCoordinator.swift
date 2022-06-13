// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import PromiseKit
import AlphaWalletAddress
import Combine

protocol TokensCoordinatorDelegate: CanOpenURL, SendTransactionDelegate {
    func didTapSwap(forTransactionType transactionType: TransactionType, service: TokenActionProvider, in coordinator: TokensCoordinator)
    func didTapBridge(forTransactionType transactionType: TransactionType, service: TokenActionProvider, in coordinator: TokensCoordinator)
    func didTapBuy(forTransactionType transactionType: TransactionType, service: TokenActionProvider, in coordinator: TokensCoordinator)
    func didPress(for type: PaymentFlow, server: RPCServer, viewController: UIViewController?, in coordinator: TokensCoordinator)
    func didTap(transaction: TransactionInstance, viewController: UIViewController, in coordinator: TokensCoordinator)
    func didTap(activity: Activity, viewController: UIViewController, in coordinator: TokensCoordinator)
    func openConsole(inCoordinator coordinator: TokensCoordinator)
    func didPostTokenScriptTransaction(_ transaction: SentTransaction, in coordinator: TokensCoordinator)
    func blockieSelected(in coordinator: TokensCoordinator)
    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TokensCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource)
    func didSentTransaction(transaction: SentTransaction, in coordinator: TokensCoordinator)

    func whereAreMyTokensSelected(in coordinator: TokensCoordinator)
    func didSelectAccount(account: Wallet, in coordinator: TokensCoordinator)
    func viewWillAppearOnce(in coordinator: TokensCoordinator)
}

class TokensCoordinator: Coordinator {
    private let sessions: ServerDictionary<WalletSession>
    private let keystore: Keystore
    private let config: Config
    private let tokenCollection: TokenCollection
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: NonActivityEventsDataStore
    private let promptBackupCoordinator: PromptBackupCoordinator
    private let analyticsCoordinator: AnalyticsCoordinator
    private let openSea: OpenSea
    private let tokenActionsService: TokenActionsService

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
            tokenCollection: tokenCollection,
            assetDefinitionStore: assetDefinitionStore,
            config: config,
            walletConnectCoordinator: walletConnectCoordinator,
            walletBalanceService: walletBalanceService,
            eventsDataStore: eventsDataStore
        )
        controller.delegate = self
        return controller
    }()

    private var sendToAddress: AlphaWallet.Address? = .none
    private var singleChainTokenCoordinators: [SingleChainTokenCoordinator] {
        return coordinators.compactMap { $0 as? SingleChainTokenCoordinator }
    }
    private let walletConnectCoordinator: WalletConnectCoordinator
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: TokensCoordinatorDelegate?

    private let coinTickersFetcher: CoinTickersFetcherType
    lazy var rootViewController: TokensViewController = {
        return tokensViewController
    }()
    private let walletBalanceService: WalletBalanceService
    private lazy var alertService: PriceAlertServiceType = {
        PriceAlertService(datastore: PriceAlertDataStore(wallet: sessions.anyValue.account), wallet: sessions.anyValue.account)
    }()

    private var tokensDataStore: TokensDataStore {
        return tokenCollection.tokensDataStore
    }
    private let tokensAutoDetectionQueue: DispatchQueue = DispatchQueue(label: "com.TokensAutoDetection.updateQueue")
    private var viewWillAppearHandled = false
    private var cancelable = Set<AnyCancellable>()
    private let blockiesGenerator: BlockiesGenerator
    private let domainResolutionService: DomainResolutionServiceType
    private let importToken: ImportToken

    init(
            navigationController: UINavigationController = .withOverridenBarAppearence(),
            sessions: ServerDictionary<WalletSession>,
            keystore: Keystore,
            config: Config,
            assetDefinitionStore: AssetDefinitionStore,
            eventsDataStore: NonActivityEventsDataStore,
            promptBackupCoordinator: PromptBackupCoordinator,
            analyticsCoordinator: AnalyticsCoordinator,
            openSea: OpenSea,
            tokenActionsService: TokenActionsService,
            walletConnectCoordinator: WalletConnectCoordinator,
            coinTickersFetcher: CoinTickersFetcherType,
            activitiesService: ActivitiesServiceType,
            walletBalanceService: WalletBalanceService,
            tokenCollection: TokenCollection,
            importToken: ImportToken,
            blockiesGenerator: BlockiesGenerator,
            domainResolutionService: DomainResolutionServiceType
    ) {
        self.tokenCollection = tokenCollection
        self.navigationController = navigationController
        self.sessions = sessions
        self.keystore = keystore
        self.config = config
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.promptBackupCoordinator = promptBackupCoordinator
        self.analyticsCoordinator = analyticsCoordinator
        self.openSea = openSea
        self.tokenActionsService = tokenActionsService
        self.walletConnectCoordinator = walletConnectCoordinator
        self.coinTickersFetcher = coinTickersFetcher
        self.activitiesService = activitiesService
        self.walletBalanceService = walletBalanceService
        self.importToken = importToken
        self.blockiesGenerator = blockiesGenerator
        self.domainResolutionService = domainResolutionService
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
        if config.development.shouldReadClipboardForWalletConnectUrl {
            if let s = UIPasteboard.general.string ?? UIPasteboard.general.url?.absoluteString, let url = AlphaWallet.WalletConnect.ConnectionUrl(s) {
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
        navigationController.viewControllers = [rootViewController]

        addUefaTokenIfAny()
        alertService.start()
    }

    deinit {
        autoDetectTransactedTokensQueue.cancelAllOperations()
        autoDetectTokensQueue.cancelAllOperations()
    }

    private func setupSingleChainTokenCoordinators() {
        for session in sessions.values {
            let tokensAutodetector: TokensAutodetector = {
                SingleChainTokensAutodetector(session: session, config: config, tokensDataStore: tokensDataStore, assetDefinitionStore: assetDefinitionStore, withAutoDetectTransactedTokensQueue: autoDetectTransactedTokensQueue, withAutoDetectTokensQueue: autoDetectTokensQueue, queue: tokensAutoDetectionQueue, importToken: importToken)
            }()

            let coordinator = SingleChainTokenCoordinator(session: session, keystore: keystore, tokensStorage: tokensDataStore, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, analyticsCoordinator: analyticsCoordinator, openSea: openSea, tokenActionsProvider: tokenActionsService, coinTickersFetcher: coinTickersFetcher, activitiesService: activitiesService, alertService: alertService, tokensAutodetector: tokensAutodetector, importToken: importToken)

            coordinator.delegate = self
            addCoordinator(coordinator)
        }
    }

    private func showTokens() {
        navigationController.viewControllers = [rootViewController]
    }

    private func addUefaTokenIfAny() {
        let server = Constants.uefaRpcServer
        importToken.importToken(for: Constants.uefaMainnet, server: server, onlyIfThereIsABalance: true)
            .done { _ in }
            .cauterize()
    }

    private func singleChainTokenCoordinator(forServer server: RPCServer) -> SingleChainTokenCoordinator? {
        return singleChainTokenCoordinators.first { $0.isServer(server) }
    }

    func listOfBadTokenScriptFilesChanged(fileNames: [TokenScriptFileIndices.FileName]) {
        tokensViewController.listOfBadTokenScriptFiles = fileNames
    }

    func launchUniversalScanner(fromSource source: Analytics.ScanQRCodeSource) {
        let account = sessions.anyValue.account
        let scanQRCodeCoordinator = ScanQRCodeCoordinator(analyticsCoordinator: analyticsCoordinator, navigationController: navigationController, account: account, domainResolutionService: domainResolutionService)

        let coordinator = QRCodeResolutionCoordinator(config: config, coordinator: scanQRCodeCoordinator, usage: .all(tokensDatastore: tokensDataStore, assetDefinitionStore: assetDefinitionStore), account: account)
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
            GetWalletName(config: config, domainResolutionService: domainResolutionService).getName(forAddress: sessions.anyValue.account.address)
        }.done { [weak self] name in
            self?.tokensViewController.navigationItem.title = name
            //Don't `cauterize` here because we don't want to PromiseKit to show the error messages from UnstoppableDomains API, suggesting there's an API error when the reason could be that the address being looked up simply does not have a registered name
            //eg.: PromiseKit:cauterized-error: UnstoppableDomainsV2ApiError(localizedDescription: "Error calling https://unstoppabledomains.g.alchemy.com API true")
        }.catch { [weak self] _ in
            self?.tokensViewController.navigationItem.title = viewModel.walletDefaultTitle
        }
    }

    private func getWalletBlockie() {
        blockiesGenerator.getBlockie(address: sessions.anyValue.account.address)
            .sink(receiveValue: { [weak tokensViewController] image in
                tokensViewController?.blockieImageView.setBlockieImage(image: image)
            }).store(in: &cancelable)
    }

    func viewWillAppear(in viewController: UIViewController) {
        getWalletName()
        getWalletBlockie()

        guard !viewWillAppearHandled else { return }
        viewWillAppearHandled = true

        delegate?.viewWillAppearOnce(in: self)
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
            strongSelf.delegate?.didPress(for: .request, server: strongSelf.config.anyEnabledServer(), viewController: .none, in: strongSelf)
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

        if Features.default.isAvailable(.isSwapEnabled) {
            let swapAction = UIAlertAction(title: "Swap", style: .default) { [weak self] _ in
                guard let strongSelf = self else { return }
                guard let service = strongSelf.tokenActionsService.service(ofType: SwapTokenNativeProvider.self) as? SwapTokenNativeProvider else { return }
                let transactionType: TransactionType = .prebuilt(strongSelf.config.anyEnabledServer())

                strongSelf.delegate?.didTapSwap(forTransactionType: transactionType, service: service, in: strongSelf)
            }

            alertController.addAction(swapAction)
        }

        let renameThisWalletAction = UIAlertAction(title: R.string.localizable.tokensWalletRenameThisWallet(), style: .default) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.didPressRenameThisWallet()
        }
        alertController.addAction(renameThisWalletAction)

        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in }
        alertController.addAction(cancelAction)

        return alertController
    }

    func walletConnectSelected(in viewController: UIViewController) {
        walletConnectCoordinator.showSessionDetails(in: navigationController)
    }

    private func didPressRenameThisWallet() {
        let viewModel = RenameWalletViewModel(account: sessions.anyValue.account.address)

        let viewController = RenameWalletViewController(viewModel: viewModel, analyticsCoordinator: analyticsCoordinator, config: config, domainResolutionService: domainResolutionService)
        viewController.delegate = self
        viewController.navigationItem.largeTitleDisplayMode = .never
        viewController.hidesBottomBarWhenPushed = true

        navigationController.pushViewController(viewController, animated: true)
    }

    private func didPressAddHideTokens(viewModel: TokensViewModel) {
        let coordinator: AddHideTokensCoordinator = .init(
            assetDefinitionStore: assetDefinitionStore,
            tokenCollection: tokenCollection,
            analyticsCoordinator: analyticsCoordinator,
            domainResolutionService: domainResolutionService,
            navigationController: navigationController,
            config: config,
            importToken: importToken)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }

    func showSingleChainToken(tokenObject: TokenObject, in navigationController: UINavigationController) {
        guard let coordinator = singleChainTokenCoordinator(forServer: tokenObject.server) else { return }

        switch tokenObject.type {
        case .nativeCryptocurrency:
            let token = Token(tokenObject: tokenObject)
            coordinator.show(fungibleToken: token, transactionType: .nativeCryptocurrency(tokenObject, destination: .none, amount: nil), navigationController: navigationController)
        case .erc20:
            let token = Token(tokenObject: tokenObject)
            coordinator.show(fungibleToken: token, transactionType: .erc20Token(tokenObject, destination: nil, amount: nil), navigationController: navigationController)
        case .erc721:
            coordinator.showTokenList(for: .send(type: .transaction(.erc721Token(tokenObject, tokenHolders: []))), token: tokenObject, navigationController: navigationController)
        case .erc875, .erc721ForTickets:
            coordinator.showTokenList(for: .send(type: .transaction(.erc875Token(tokenObject, tokenHolders: []))), token: tokenObject, navigationController: navigationController)
        case .erc1155:
            coordinator.showTokenList(for: .send(type: .transaction(.erc1155Token(tokenObject, transferType: .singleTransfer, tokenHolders: []))), token: tokenObject, navigationController: navigationController)
        }
    }

    func didSelect(token: Token, in viewController: UIViewController) {
        guard let tokenObject = tokensDataStore.tokenObject(forContract: token.contractAddress, server: token.server) else { return }
        showSingleChainToken(tokenObject: tokenObject, in: navigationController)
    }

    func didHide(token: Token, in viewController: UIViewController) {
        tokensDataStore.updateToken(primaryKey: token.primaryKey, action: .isHidden(true))
    }

    func didTapOpenConsole(in viewController: UIViewController) {
        delegate?.openConsole(inCoordinator: self)
    }
}

extension TokensCoordinator: RenameWalletViewControllerDelegate {

    func didFinish(in viewController: RenameWalletViewController) {
        navigationController.popViewController(animated: true)
    }
}

extension TokensCoordinator: SelectTokenCoordinatorDelegate {

    func coordinator(_ coordinator: SelectTokenCoordinator, didSelectToken token: Token) {
        removeCoordinator(coordinator)
        guard let tokenObject = tokensDataStore.tokenObject(forContract: token.contractAddress, server: token.server) else { return }
        switch sendToAddress {
        case .some(let address):
            let paymentFlow = PaymentFlow.send(type: .transaction(.init(fungibleToken: tokenObject, recipient: .address(address), amount: nil)))

            delegate?.didPress(for: paymentFlow, server: tokenObject.server, viewController: .none, in: self)
        case .none:
            break
        }
        sendToAddress = .none
    }

    func didCancel(in coordinator: SelectTokenCoordinator) {
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

        delegate?.didPress(for: paymentFlow, server: token.server, viewController: .none, in: self)
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
            config: config,
            importToken: importToken,
            initialState: .address(address),
            domainResolutionService: domainResolutionService)
        coordinator.delegate = self
        addCoordinator(coordinator)

        coordinator.start()
    }

    private func handleSendToAddress(_ address: AlphaWallet.Address) {
        sendToAddress = address

        let coordinator = SelectTokenCoordinator(
            assetDefinitionStore: assetDefinitionStore,
            wallet: sessions.anyValue.account,
            tokenBalanceService: sessions.anyValue.tokenBalanceService,
            tokenCollection: tokenCollection,
            navigationController: navigationController,
            filter: .filter(NativeCryptoOrErc20TokenFilter()),
            eventsDataStore: eventsDataStore
        )
        coordinator.delegate = self
        addCoordinator(coordinator)

        coordinator.start()
    }

    private func handleWatchWallet(_ address: AlphaWallet.Address) {
        let walletCoordinator = WalletCoordinator(config: config, keystore: keystore, analyticsCoordinator: analyticsCoordinator, domainResolutionService: domainResolutionService)
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

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveWalletConnectURL url: AlphaWallet.WalletConnect.ConnectionUrl) {
        removeCoordinator(coordinator)
        walletConnectCoordinator.openSession(url: url)
    }

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveString value: String) {
        removeCoordinator(coordinator)
    }
}

extension TokensCoordinator: NewTokenCoordinatorDelegate {

    func coordinator(_ coordinator: NewTokenCoordinator, didAddToken token: Token) {
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
        delegate?.didSelectAccount(account: account, in: self)
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

    func didTapAddAlert(for token: Token, in coordinator: SingleChainTokenCoordinator) {
        let coordinatorToAdd = EditPriceAlertCoordinator(navigationController: navigationController, configuration: .create, token: token, session: coordinator.session, alertService: alertService)
        addCoordinator(coordinatorToAdd)
        coordinatorToAdd.delegate = self
        coordinatorToAdd.start()
    }

    func didTapEditAlert(for token: Token, alert: PriceAlert, in coordinator: SingleChainTokenCoordinator) {
        let coordinatorToAdd = EditPriceAlertCoordinator(navigationController: navigationController, configuration: .edit(alert), token: token, session: coordinator.session, alertService: alertService)
        addCoordinator(coordinatorToAdd)
        coordinatorToAdd.delegate = self
        coordinatorToAdd.start()
    }

    func didTapSwap(forTransactionType transactionType: TransactionType, service: TokenActionProvider, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didTapSwap(forTransactionType: transactionType, service: service, in: self)
    }

    func didTapBridge(forTransactionType transactionType: TransactionType, service: TokenActionProvider, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didTapBridge(forTransactionType: transactionType, service: service, in: self)
    }

    func didTapBuy(forTransactionType transactionType: TransactionType, service: TokenActionProvider, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didTapBuy(forTransactionType: transactionType, service: service, in: self)
    }

    func didPress(for type: PaymentFlow, viewController: UIViewController, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didPress(for: type, server: coordinator.session.server, viewController: viewController, in: self)
    }

    func didTap(activity: Activity, viewController: UIViewController, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didTap(activity: activity, viewController: viewController, in: self)
    }

    func didTap(transaction: TransactionInstance, viewController: UIViewController, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didTap(transaction: transaction, viewController: viewController, in: self)
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
    func didClose(in coordinator: AddHideTokensCoordinator) {
        removeCoordinator(coordinator)
    }
}
