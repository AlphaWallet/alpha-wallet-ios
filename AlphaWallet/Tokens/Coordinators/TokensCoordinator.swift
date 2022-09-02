// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletAddress
import Combine
import AlphaWalletFoundation

protocol TokensCoordinatorDelegate: CanOpenURL, SendTransactionDelegate, BuyCryptoDelegate {
    func didTapSwap(swapTokenFlow: SwapTokenFlow, in coordinator: TokensCoordinator)
    func didTapBridge(transactionType: TransactionType, service: TokenActionProvider, in coordinator: TokensCoordinator)
    func didTapBuy(transactionType: TransactionType, service: TokenActionProvider, in coordinator: TokensCoordinator)
    func didTap(suggestedPaymentFlow: SuggestedPaymentFlow, viewController: UIViewController?, in coordinator: TokensCoordinator)
    func didTap(transaction: TransactionInstance, viewController: UIViewController, in coordinator: TokensCoordinator)
    func didTap(activity: Activity, viewController: UIViewController, in coordinator: TokensCoordinator)
    func openConsole(inCoordinator coordinator: TokensCoordinator)
    func didPostTokenScriptTransaction(_ transaction: SentTransaction, in coordinator: TokensCoordinator)
    func blockieSelected(in coordinator: TokensCoordinator)
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
    private let promptBackupCoordinator: PromptBackupCoordinator
    private let analytics: AnalyticsLogger
    private let openSea: OpenSea
    private let tokenActionsService: TokenActionsService
    private let tokensFilter: TokensFilter
    private let activitiesService: ActivitiesServiceType
    //NOTE: private (set) - `For test purposes only`
    private (set) lazy var tokensViewController: TokensViewController = {
        let viewModel = TokensViewModel(wallet: wallet, tokenCollection: tokenCollection, tokensFilter: tokensFilter, walletConnectCoordinator: walletConnectCoordinator, walletBalanceService: walletBalanceService, config: config, domainResolutionService: domainResolutionService, blockiesGenerator: blockiesGenerator)
        let controller = TokensViewController(viewModel: viewModel)

        controller.delegate = self

        return controller
    }()

    private var singleChainTokenCoordinators: [SingleChainTokenCoordinator] {
        return coordinators.compactMap { $0 as? SingleChainTokenCoordinator }
    }
    private let walletConnectCoordinator: WalletConnectCoordinator
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: TokensCoordinatorDelegate?

    private let coinTickersFetcher: CoinTickersFetcher
    lazy var rootViewController: TokensViewController = {
        return tokensViewController
    }()
    private let walletBalanceService: WalletBalanceService
    private lazy var alertService: PriceAlertServiceType = {
        PriceAlertService(datastore: PriceAlertDataStore(wallet: wallet), wallet: wallet)
    }()

    private var viewWillAppearHandled = false
    private let blockiesGenerator: BlockiesGenerator
    private let domainResolutionService: DomainResolutionServiceType
    private let importToken: ImportToken
    private let wallet: Wallet
    
    init(
            navigationController: UINavigationController = .withOverridenBarAppearence(),
            sessions: ServerDictionary<WalletSession>,
            keystore: Keystore,
            config: Config,
            assetDefinitionStore: AssetDefinitionStore,
            promptBackupCoordinator: PromptBackupCoordinator,
            analytics: AnalyticsLogger,
            openSea: OpenSea,
            tokenActionsService: TokenActionsService,
            walletConnectCoordinator: WalletConnectCoordinator,
            coinTickersFetcher: CoinTickersFetcher,
            activitiesService: ActivitiesServiceType,
            walletBalanceService: WalletBalanceService,
            tokenCollection: TokenCollection,
            importToken: ImportToken,
            blockiesGenerator: BlockiesGenerator,
            domainResolutionService: DomainResolutionServiceType,
            tokensFilter: TokensFilter
    ) {
        self.wallet = sessions.anyValue.account
        self.tokensFilter = tokensFilter
        self.tokenCollection = tokenCollection
        self.navigationController = navigationController
        self.sessions = sessions
        self.keystore = keystore
        self.config = config
        self.assetDefinitionStore = assetDefinitionStore
        self.promptBackupCoordinator = promptBackupCoordinator
        self.analytics = analytics
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
        navigationController.viewControllers = [rootViewController]

        alertService.start()
    }

    private func setupSingleChainTokenCoordinators() {
        for session in sessions.values {
            let coordinator = SingleChainTokenCoordinator(session: session, keystore: keystore, assetDefinitionStore: assetDefinitionStore, analytics: analytics, openSea: openSea, tokenActionsProvider: tokenActionsService, coinTickersFetcher: coinTickersFetcher, activitiesService: activitiesService, alertService: alertService, tokensService: tokenCollection, sessions: sessions)

            coordinator.delegate = self
            addCoordinator(coordinator)
        }
    }

    private func showTokens() {
        navigationController.viewControllers = [rootViewController]
    }

    private func singleChainTokenCoordinator(forServer server: RPCServer) -> SingleChainTokenCoordinator? {
        return singleChainTokenCoordinators.first { $0.isServer(server) }
    }

    func listOfBadTokenScriptFilesChanged(fileNames: [TokenScriptFileIndices.FileName]) {
        tokensViewController.viewModel.set(listOfBadTokenScriptFiles: fileNames)
    }

    func launchUniversalScanner(fromSource source: Analytics.ScanQRCodeSource) {
        let scanQRCodeCoordinator = ScanQRCodeCoordinator(analytics: analytics, navigationController: navigationController, account: wallet, domainResolutionService: domainResolutionService)
        let coordinator = QRCodeResolutionCoordinator(config: config, coordinator: scanQRCodeCoordinator, usage: .all(tokensService: tokenCollection, assetDefinitionStore: assetDefinitionStore), account: wallet, analytics: analytics)
        coordinator.delegate = self

        addCoordinator(coordinator)

        coordinator.start(fromSource: source, clipboardString: UIPasteboard.general.stringForQRCode)
    }
}

extension UIPasteboard {
    var stringForQRCode: String? {
        guard Config().development.shouldReadClipboardForQRCode else { return nil }
        return UIPasteboard.general.string ?? UIPasteboard.general.url?.absoluteString
    }
}

extension TokensCoordinator: TokensViewControllerDelegate {

    func whereAreMyTokensSelected(in viewController: UIViewController) {
        delegate?.whereAreMyTokensSelected(in: self)
    }
    
    func viewWillAppear(in viewController: UIViewController) {
        guard !viewWillAppearHandled else { return }
        viewWillAppearHandled = true

        delegate?.viewWillAppearOnce(in: self)
    }

    private func makeMoreAlertSheet(sender: UIBarButtonItem) -> UIAlertController {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.popoverPresentationController?.barButtonItem = sender

        let server: RPCServer = sessions.anyValue.server

        let copyAddressAction = UIAlertAction(title: R.string.localizable.copyAddress(), style: .default) { [weak self] _ in
            guard let strongSelf = self else { return }
            UIPasteboard.general.string = strongSelf.wallet.address.eip55String
            strongSelf.tokensViewController.view.showCopiedToClipboard(title: R.string.localizable.copiedToClipboard())
        }
        alertController.addAction(copyAddressAction)

        let showMyWalletAddressAction = UIAlertAction(title: R.string.localizable.settingsShowMyWalletTitle(), style: .default) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.didTap(suggestedPaymentFlow: .payment(type: .request, server: server), viewController: .none, in: strongSelf)
        }
        alertController.addAction(showMyWalletAddressAction)

        if config.enabledServers.contains(.main) {
            let buyAction = UIAlertAction(title: R.string.localizable.buyCryptoTitle(), style: .default) { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.buyCrypto(wallet: strongSelf.wallet, server: .main, viewController: strongSelf.tokensViewController, source: .walletTab)
            }
            alertController.addAction(buyAction)
        }

        let addHideTokensAction = UIAlertAction(title: R.string.localizable.walletsAddHideTokensTitle(), style: .default) { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.didPressAddHideTokens()
        }
        alertController.addAction(addHideTokensAction)

        let swapAction = UIAlertAction(title: "Swap", style: .default) { [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.delegate?.didTapSwap(swapTokenFlow: .selectTokenToSwap, in: strongSelf)
        }

        alertController.addAction(swapAction)

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
        let viewModel = RenameWalletViewModel(account: wallet.address, analytics: analytics, domainResolutionService: domainResolutionService)

        let viewController = RenameWalletViewController(viewModel: viewModel)
        viewController.delegate = self
        viewController.navigationItem.largeTitleDisplayMode = .never
        viewController.hidesBottomBarWhenPushed = true

        navigationController.pushViewController(viewController, animated: true)
    }

    private func didPressAddHideTokens() {
        let coordinator: AddHideTokensCoordinator = .init(
            tokensFilter: tokensFilter,
            tokenCollection: tokenCollection,
            analytics: analytics,
            domainResolutionService: domainResolutionService,
            navigationController: navigationController,
            config: config,
            importToken: importToken)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }

    func showSingleChainToken(token: Token, in navigationController: UINavigationController) {
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

    func didSelect(token: Token, in viewController: UIViewController) {
        showSingleChainToken(token: token, in: navigationController)
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

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveTransactionType transactionType: TransactionType, token: Token) {
        removeCoordinator(coordinator)

        delegate?.didTap(suggestedPaymentFlow: .payment(type: .send(type: .transaction(transactionType)), server: token.server), viewController: .none, in: self)
    }

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolveAddress address: AlphaWallet.Address, action: ScanQRCodeAction) {
        removeCoordinator(coordinator)

        switch action {
        case .addCustomToken:
            handleAddCustomToken(address)
        case .sendToAddress:
            delegate?.didTap(suggestedPaymentFlow: .other(value: .sendToRecipient(recipient: .address(address))), viewController: .none, in: self)
        case .watchWallet:
            handleWatchWallet(address)
        case .openInEtherscan:
            delegate?.didPressViewContractWebPage(forContract: address, server: config.anyEnabledServer(), in: tokensViewController)
        }
    }

    private func handleAddCustomToken(_ address: AlphaWallet.Address) {
        let coordinator = NewTokenCoordinator(
            analytics: analytics,
            navigationController: navigationController,
            config: config,
            importToken: importToken,
            initialState: .address(address),
            domainResolutionService: domainResolutionService)
        coordinator.delegate = self
        addCoordinator(coordinator)

        coordinator.start()
    }

    private func handleWatchWallet(_ address: AlphaWallet.Address) {
        let walletCoordinator = WalletCoordinator(config: config, keystore: keystore, analytics: analytics, domainResolutionService: domainResolutionService)
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
        let coordinatorToAdd = EditPriceAlertCoordinator(navigationController: navigationController, configuration: .create, token: token, session: coordinator.session, tokensService: tokenCollection, alertService: alertService)
        addCoordinator(coordinatorToAdd)
        coordinatorToAdd.delegate = self
        coordinatorToAdd.start()
    }

    func didTapEditAlert(for token: Token, alert: PriceAlert, in coordinator: SingleChainTokenCoordinator) {
        let coordinatorToAdd = EditPriceAlertCoordinator(navigationController: navigationController, configuration: .edit(alert), token: token, session: coordinator.session, tokensService: tokenCollection, alertService: alertService)
        addCoordinator(coordinatorToAdd)
        coordinatorToAdd.delegate = self
        coordinatorToAdd.start()
    }

    func didTapSwap(swapTokenFlow: SwapTokenFlow, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didTapSwap(swapTokenFlow: swapTokenFlow, in: self)
    }

    func didTapBridge(transactionType: TransactionType, service: TokenActionProvider, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didTapBridge(transactionType: transactionType, service: service, in: self)
    }

    func didTapBuy(transactionType: TransactionType, service: TokenActionProvider, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didTapBuy(transactionType: transactionType, service: service, in: self)
    }

    func didPress(for type: PaymentFlow, viewController: UIViewController, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didTap(suggestedPaymentFlow: .payment(type: type, server: coordinator.session.server), viewController: viewController, in: self)
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
