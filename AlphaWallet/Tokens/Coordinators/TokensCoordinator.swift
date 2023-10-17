// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletAttestation
import AlphaWalletAddress
import AlphaWalletCore
import AlphaWalletLogger
import Combine
import AlphaWalletFoundation

protocol TokensCoordinatorDelegate: CanOpenURL, SendTransactionDelegate, BuyCryptoDelegate {
    func didTapSwap(swapTokenFlow: SwapTokenFlow, in coordinator: TokensCoordinator)
    func didTapBridge(token: Token, service: TokenActionProvider, in coordinator: TokensCoordinator)
    func didTapBuy(token: Token, service: TokenActionProvider, in coordinator: TokensCoordinator)
    func didTap(suggestedPaymentFlow: SuggestedPaymentFlow, viewController: UIViewController?, in coordinator: TokensCoordinator)
    func didTap(transaction: Transaction, viewController: UIViewController, in coordinator: TokensCoordinator)
    func didTap(activity: Activity, viewController: UIViewController, in coordinator: TokensCoordinator)
    func openConsole(inCoordinator coordinator: TokensCoordinator)
    func didPostTokenScriptTransaction(_ transaction: SentTransaction, in coordinator: TokensCoordinator)
    func blockieSelected(in coordinator: TokensCoordinator)
    func didSentTransaction(transaction: SentTransaction, in coordinator: TokensCoordinator)

    func didSelectAccount(account: Wallet, in coordinator: TokensCoordinator)
    func viewWillAppearOnce(in coordinator: TokensCoordinator)
    func importAttestation(_ attestation: Attestation) async -> Bool
}

class TokensCoordinator: Coordinator {
    private let sessionsProvider: SessionsProvider
    private let keystore: Keystore
    private let config: Config
    private let tokensPipeline: TokensProcessingPipeline
    private let assetDefinitionStore: AssetDefinitionStore
    private let promptBackupCoordinator: PromptBackupCoordinator
    private let analytics: AnalyticsLogger
    private let tokenActionsService: TokenActionsService
    private let tokensFilter: TokensFilter
    private let activitiesService: ActivitiesServiceType
    private let tokenImageFetcher: TokenImageFetcher
    //NOTE: private (set) - `For test purposes only`
    private (set) lazy var tokensViewController: TokensViewController = {
        let viewModel = TokensViewModel(
            wallet: wallet,
            tokensPipeline: tokensPipeline,
            tokensFilter: tokensFilter,
            walletConnectProvider: walletConnectCoordinator.walletConnectProvider,
            walletBalanceService: walletBalanceService,
            config: config,
            domainResolutionService: domainResolutionService,
            blockiesGenerator: blockiesGenerator,
            assetDefinitionStore: assetDefinitionStore,
            tokenImageFetcher: tokenImageFetcher,
            serversProvider: serversProvider,
            tokensService: tokensService,
            attestationsStore: attestationsStore)

        let controller = TokensViewController(viewModel: viewModel)

        controller.delegate = self

        return controller
    }()

    private var singleChainTokenCoordinators: [SingleChainTokenCoordinator] {
        return coordinators.compactMap { $0 as? SingleChainTokenCoordinator }
    }
    private let walletConnectCoordinator: WalletConnectCoordinator
    private let coinTickersProvider: CoinTickersProvider

    private let walletBalanceService: WalletBalanceService
    private lazy var alertService: PriceAlertServiceType = {
        PriceAlertService(datastore: PriceAlertDataStore(wallet: wallet), wallet: wallet)
    }()

    private var viewWillAppearHandled = false
    private let blockiesGenerator: BlockiesGenerator
    private let domainResolutionService: DomainNameResolutionServiceType
    private let wallet: Wallet
    private let currencyService: CurrencyService
    private var cancellable = Set<AnyCancellable>()
    private let serversProvider: ServersProvidable
    private let tokensService: TokensService
    private let attestationsStore: AttestationsStore

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: TokensCoordinatorDelegate?
    lazy var rootViewController: TokensViewController = {
        return tokensViewController
    }()

    init(navigationController: UINavigationController = .withOverridenBarAppearence(),
         sessionsProvider: SessionsProvider,
         keystore: Keystore,
         config: Config,
         assetDefinitionStore: AssetDefinitionStore,
         promptBackupCoordinator: PromptBackupCoordinator,
         analytics: AnalyticsLogger,
         tokenActionsService: TokenActionsService,
         walletConnectCoordinator: WalletConnectCoordinator,
         coinTickersProvider: CoinTickersProvider,
         activitiesService: ActivitiesServiceType,
         walletBalanceService: WalletBalanceService,
         tokenCollection: TokensProcessingPipeline,
         tokensService: TokensService,
         blockiesGenerator: BlockiesGenerator,
         domainResolutionService: DomainNameResolutionServiceType,
         tokensFilter: TokensFilter,
         currencyService: CurrencyService,
         tokenImageFetcher: TokenImageFetcher,
         serversProvider: ServersProvidable,
         attestationsStore: AttestationsStore) {
        self.tokensService = tokensService
        self.serversProvider = serversProvider
        self.tokenImageFetcher = tokenImageFetcher
        self.currencyService = currencyService
        self.wallet = sessionsProvider.activeSessions.anyValue.account
        self.tokensFilter = tokensFilter
        self.tokensPipeline = tokenCollection
        self.navigationController = navigationController
        self.sessionsProvider = sessionsProvider
        self.keystore = keystore
        self.config = config
        self.assetDefinitionStore = assetDefinitionStore
        self.promptBackupCoordinator = promptBackupCoordinator
        self.analytics = analytics
        self.tokenActionsService = tokenActionsService
        self.walletConnectCoordinator = walletConnectCoordinator
        self.coinTickersProvider = coinTickersProvider
        self.activitiesService = activitiesService
        self.walletBalanceService = walletBalanceService
        self.blockiesGenerator = blockiesGenerator
        self.domainResolutionService = domainResolutionService
        self.attestationsStore = attestationsStore

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
            showUniversalScanner(fromSource: .walletScreen)
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
        sessionsProvider.sessions
            .sink { [weak self] sessions in
                guard let strongSelf = self else { return }

                var coordinators: [SingleChainTokenCoordinator] = []
                for session in sessions {
                    if let coordinator = strongSelf.singleChainTokenCoordinator(forServer: session.key) {
                        coordinators += [coordinator]
                    } else {
                        coordinators += [strongSelf.buildSingleChainTokenCoordinator(for: session.value)]
                    }
                }

                let coordinatorsToDelete = strongSelf.singleChainTokenCoordinators.filter { c in !coordinators.contains(where: { $0.server == c.server }) }
                coordinatorsToDelete.forEach { strongSelf.removeCoordinator($0) }
            }.store(in: &cancellable)
    }

    private func buildSingleChainTokenCoordinator(for session: WalletSession) -> SingleChainTokenCoordinator {
        let coordinator = SingleChainTokenCoordinator(
            session: session,
            keystore: keystore,
            assetDefinitionStore: assetDefinitionStore,
            analytics: analytics,
            nftProvider: session.nftProvider,
            tokenActionsProvider: tokenActionsService,
            coinTickersProvider: coinTickersProvider,
            activitiesService: activitiesService,
            alertService: alertService,
            tokensPipeline: tokensPipeline,
            sessionsProvider: sessionsProvider,
            currencyService: currencyService,
            tokenImageFetcher: tokenImageFetcher,
            tokensService: tokensService)

        coordinator.delegate = self
        addCoordinator(coordinator)

        return coordinator
    }

    private func showTokens() {
        navigationController.viewControllers = [rootViewController]
    }

    private func singleChainTokenCoordinator(forServer server: RPCServer) -> SingleChainTokenCoordinator? {
        return singleChainTokenCoordinators.first { $0.isServer(server) }
    }

    func showUniversalScanner(fromSource source: Analytics.ScanQRCodeSource) {
        let scanQRCodeCoordinator = ScanQRCodeCoordinator(
            analytics: analytics,
            navigationController: navigationController,
            account: wallet,
            domainResolutionService: domainResolutionService)

        let coordinator = QRCodeResolutionCoordinator(
            coordinator: scanQRCodeCoordinator,
            usage: .all(tokensService: tokensService, sessionsProvider: sessionsProvider))

        coordinator.delegate = self

        addCoordinator(coordinator)

        coordinator.start(fromSource: source, clipboardString: UIPasteboard.general.stringForQRCode)
    }

    private func displayAttestation(_ attestation: Attestation) {
        infoLog("[Attestation] Display attestation: \(attestation) scriptURI TokenScript file in (it might be overridden): \(String(describing: assetDefinitionStore.debugFilenameHoldingAttestationScriptUri(forAttestation: attestation)))")
        let vc = AttestationViewController(attestation: attestation, wallet: wallet, assetDefinitionStore: assetDefinitionStore)
        vc.delegate = self
        vc.hidesBottomBarWhenPushed = true
        vc.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(vc, animated: true)
    }

    private func importAttestation(_ attestation: Attestation) {
        Task { @MainActor in
            _ = await delegate?.importAttestation(attestation)
        }
    }
}

extension UIPasteboard {
    var stringForQRCode: String? {
        guard Config().development.shouldReadClipboardForQRCode else { return nil }
        return UIPasteboard.general.string ?? UIPasteboard.general.url?.absoluteString
    }
}

extension TokensCoordinator: TokensViewControllerDelegate {

    func buyCryptoSelected(in viewController: UIViewController) {
        delegate?.buyCrypto(wallet: wallet, server: .main, viewController: viewController, source: .walletTab)
    }

    func viewWillAppear(in viewController: UIViewController) {
        guard !viewWillAppearHandled else { return }
        viewWillAppearHandled = true

        delegate?.viewWillAppearOnce(in: self)
    }

    private func makeMoreAlertSheet(sender: UIBarButtonItem) -> UIAlertController {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.popoverPresentationController?.barButtonItem = sender

        let server: RPCServer = sessionsProvider.activeSessions.anyValue.server

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

        if sessionsProvider.session(for: .main) != nil && Features.current.isAvailable(.buyCryptoEnabled) {
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

        if Features.current.isAvailable(.isSwapEnabled) {
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
        let viewModel = RenameWalletViewModel(
            account: wallet.address,
            analytics: analytics,
            domainResolutionService: domainResolutionService)

        let viewController = RenameWalletViewController(viewModel: viewModel)
        viewController.delegate = self
        viewController.navigationItem.largeTitleDisplayMode = .never
        viewController.hidesBottomBarWhenPushed = true

        navigationController.pushViewController(viewController, animated: true)
    }

    private func didPressAddHideTokens() {
        let coordinator: AddHideTokensCoordinator = .init(
            tokensFilter: tokensFilter,
            wallet: wallet,
            tokenCollection: tokensPipeline,
            analytics: analytics,
            domainResolutionService: domainResolutionService,
            navigationController: navigationController,
            serversProvider: serversProvider,
            sessionsProvider: sessionsProvider,
            tokenImageFetcher: tokenImageFetcher,
            tokensService: tokensService)

        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }

    func showSingleChainToken(token: Token, in navigationController: UINavigationController) {
        guard let coordinator = singleChainTokenCoordinator(forServer: token.server) else { return }
        switch token.type {
        case .nativeCryptocurrency, .erc20:
            coordinator.show(fungibleToken: token, navigationController: navigationController)
        case .erc721, .erc875, .erc721ForTickets, .erc1155:
            coordinator.show(nonFungibleToken: token, navigationController: navigationController)
        }
    }

    func didSelect(token: Token, in viewController: UIViewController) {
        showSingleChainToken(token: token, in: navigationController)
    }

    func didSelect(attestation: Attestation, in viewController: UIViewController) {
        displayAttestation(attestation)
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
    func didCancel(in coordinator: QRCodeResolutionCoordinator) {
        removeCoordinator(coordinator)
    }

    func coordinator(_ coordinator: QRCodeResolutionCoordinator, didResolve qrCodeResolution: QrCodeResolution) {
        switch qrCodeResolution {
        case .walletConnectUrl(let url):
            walletConnectCoordinator.openSession(url: url)
        case .transactionType(let transactionType, let token):
            delegate?.didTap(suggestedPaymentFlow: .payment(type: .send(type: .transaction(transactionType)), server: token.server), viewController: .none, in: self)
        case .address(let address, let action):
            switch action {
            case .addCustomToken:
                handleAddCustomToken(address)
            case .sendToAddress:
                delegate?.didTap(suggestedPaymentFlow: .other(value: .sendToRecipient(recipient: .address(address))), viewController: .none, in: self)
            case .watchWallet:
                handleImportOrWatchWallet(.watchWallet(address: address))
            case .openInEtherscan:
                delegate?.didPressViewContractWebPage(forContract: address, server: config.anyEnabledServer(), in: tokensViewController)
            }
        case .url(let url):
            delegate?.didPressOpenWebPage(url, in: tokensViewController)
        case .string:
            break
        case .json(let json):
            handleImportOrWatchWallet(.importWallet(params: .json(json: json)))
        case .seedPhase(let seedPhase):
            handleImportOrWatchWallet(.importWallet(params: .seedPhase(seedPhase: seedPhase)))
        case .privateKey(let privateKey):
            handleImportOrWatchWallet(.importWallet(params: .privateKey(privateKey: privateKey)))
        case .attestation(let attestation):
            //TODO prompt user to import the attestation?
            importAttestation(attestation)
        }

        removeCoordinator(coordinator)
    }

    private func handleAddCustomToken(_ address: AlphaWallet.Address) {
        let coordinator = NewTokenCoordinator(
            analytics: analytics,
            wallet: wallet,
            navigationController: navigationController,
            serversProvider: serversProvider,
            sessionsProvider: sessionsProvider,
            initialState: .address(address),
            domainResolutionService: domainResolutionService)

        coordinator.delegate = self
        addCoordinator(coordinator)

        coordinator.start()
    }

    private func handleImportOrWatchWallet(_ entryPoint: WalletEntryPoint) {
        let walletCoordinator = WalletCoordinator(
            config: config,
            keystore: keystore,
            analytics: analytics,
            domainResolutionService: domainResolutionService)

        walletCoordinator.delegate = self

        addCoordinator(walletCoordinator)

        walletCoordinator.start(entryPoint)
        walletCoordinator.navigationController.makePresentationFullScreenForiOS13Migration()

        navigationController.present(walletCoordinator.navigationController, animated: true)
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
        let coordinatorToAdd = EditPriceAlertCoordinator(
            navigationController: navigationController,
            configuration: .create,
            token: token,
            session: coordinator.session,
            tokensService: tokensPipeline,
            alertService: alertService,
            currencyService: currencyService,
            tokenImageFetcher: tokenImageFetcher)

        addCoordinator(coordinatorToAdd)
        coordinatorToAdd.delegate = self
        coordinatorToAdd.start()
    }

    func didTapEditAlert(for token: Token, alert: PriceAlert, in coordinator: SingleChainTokenCoordinator) {
        let coordinatorToAdd = EditPriceAlertCoordinator(
            navigationController: navigationController,
            configuration: .edit(alert),
            token: token,
            session: coordinator.session,
            tokensService: tokensPipeline,
            alertService: alertService,
            currencyService: currencyService,
            tokenImageFetcher: tokenImageFetcher)

        addCoordinator(coordinatorToAdd)
        coordinatorToAdd.delegate = self
        coordinatorToAdd.start()
    }

    func didTapSwap(swapTokenFlow: SwapTokenFlow, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didTapSwap(swapTokenFlow: swapTokenFlow, in: self)
    }

    func didTapBridge(token: Token, service: TokenActionProvider, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didTapBridge(token: token, service: service, in: self)
    }

    func didTapBuy(token: Token, service: TokenActionProvider, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didTapBuy(token: token, service: service, in: self)
    }

    func didPress(for type: PaymentFlow, viewController: UIViewController, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didTap(suggestedPaymentFlow: .payment(type: type, server: coordinator.session.server), viewController: viewController, in: self)
    }

    func didTap(activity: Activity, viewController: UIViewController, in coordinator: SingleChainTokenCoordinator) {
        delegate?.didTap(activity: activity, viewController: viewController, in: self)
    }

    func didTap(transaction: Transaction, viewController: UIViewController, in coordinator: SingleChainTokenCoordinator) {
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

extension TokensCoordinator: AttestationViewControllerDelegate {
}

extension TokensCoordinator: AttestationsViewControllerDelegate {
    func openAttestation(_ attestation: Attestation, fromViewController: AttestationsViewController) {
        displayAttestation(attestation)
    }
}
