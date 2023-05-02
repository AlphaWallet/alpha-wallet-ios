//
//  Application.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.04.2023.
//

import Combine
import UIKit
import AlphaWalletAddress
import AlphaWalletCore
import AlphaWalletFoundation
import AlphaWalletLogger
import AlphaWalletTrackAPICalls

extension TokenScript {
    static let baseTokenScriptFiles: [TokenType: String] = [
        .erc20: (try! String(contentsOf: R.file.erc20TokenScriptTsml()!)),
        .erc721: (try! String(contentsOf: R.file.erc721TokenScriptTsml()!)),
    ]
}

protocol ApplicationNavigatable: AnyObject {
    func showActiveWalletIfNeeded()
    func launchUniversalScanner(fromSource: Analytics.ScanQRCodeSource)
    func showQrCode()
    func openUrlInDappBrowser(url: URL, animated: Bool)
    func show(error: Error)
    func showTokenScriptFileImported(filename: String)
    func openWalletConnectSession(url: AlphaWallet.WalletConnect.ConnectionUrl)
    func showPaymentFlow(for type: PaymentFlow, server: RPCServer)
    func showImportMagicLink(session: WalletSession, url: URL)
    func showServerUnavailable(server: RPCServer)
    func showWalletApi(action: DeepLink.WalletApi)
}

// swiftlint:disable type_body_length
class Application: WalletDependenciesProvidable {
    //TODO rename and replace type? Not Initializer but similar as of writing
    private var services: [Initializer] = []
    private let dependencies: AtomicDictionary<Wallet, WalletDependencies> = .init()
    private var cancelable = Set<AnyCancellable>()
    private let launchOptionsService: LaunchOptionsService
    private let userActivityService: UserActivityService
    private let shortcutHandler: ShortcutHandler

    let config: Config
    let legacyFileBasedKeystore: LegacyFileBasedKeystore
    let lock: Lock
    let keystore: Keystore
    let assetDefinitionStore: AssetDefinitionStore
    let appTracker: AppTracker
    let universalLinkService: UniversalLinkService
    let analytics: AnalyticsServiceType
    let restartHandler: RestartQueueHandler
    let currencyService: CurrencyService
    let coinTickersFetcher: CoinTickersFetcher
    let walletBalanceService: WalletBalanceService & WalletBalanceProvidable
    let networkService: NetworkService
    let tokenSwapper: TokenSwapper
    let tokenActionsService: TokenActionsService
    let serversProvider: ServersProvidable
    let caip10AccountProvidable: CAIP10AccountProvidable
    let walletConnectProvider: WalletConnectProvider
    let blockiesGenerator: BlockiesGenerator
    let domainResolutionService: DomainResolutionServiceType
    let notificationService: NotificationService
    let blockchainsProvider: BlockchainsProvider
    let reachability = ReachabilityManager()
    let securedStorage: SecuredPasswordStorage & SecuredStorage
    let tokenScriptOverridesFileManager = TokenScriptOverridesFileManager()
    let apiTransporterFactory = ApiTransporterFactory()
    let tokenImageFetcher: TokenImageFetcher
    let tokenGroupIdentifier: TokenGroupIdentifierProtocol
    let promptBackup: PromptBackup
    let mediaContentDownloader: MediaContentDownloader

    weak var navigation: ApplicationNavigatable?

    static let shared: Application = try! Application()

    convenience init() throws {
        crashlytics.register(AlphaWallet.FirebaseCrashlyticsReporter.instance)

        let analytics = AnalyticsService()
        let walletAddressesStore: WalletAddressesStore = EtherKeystore.migratedWalletAddressesStore(userDefaults: .standardOrForTests)
        let securedStorage: SecuredStorage & SecuredPasswordStorage = try KeychainStorage()
        let legacyFileBasedKeystore = try LegacyFileBasedKeystore(securedStorage: securedStorage)

        let keystore: Keystore = EtherKeystore(
            keychain: securedStorage,
            walletAddressesStore: walletAddressesStore,
            analytics: analytics,
            legacyFileBasedKeystore: legacyFileBasedKeystore,
            hardwareWalletFactory: BCHardwareWalletCreator())

        self.init(
            analytics: analytics,
            keystore: keystore,
            securedStorage: securedStorage,
            legacyFileBasedKeystore: legacyFileBasedKeystore)
    }

    init(analytics: AnalyticsServiceType,
         keystore: Keystore,
         securedStorage: SecuredPasswordStorage & SecuredStorage,
         legacyFileBasedKeystore: LegacyFileBasedKeystore,
         config: Config = Config()) {

        self.config = config
        let addressStorage = FileAddressStorage()
        register(addressStorage: addressStorage)

        self.appTracker = AppTracker()
        self.lock = SecuredLock(securedStorage: securedStorage)
        self.serversProvider = BaseServersProvider(config: config)
        self.caip10AccountProvidable = AnyCAIP10AccountProvidable(keystore: keystore, serversProvidable: serversProvider)
        self.currencyService = CurrencyService(storage: config)
        self.walletBalanceService = MultiWalletBalanceService(currencyService: currencyService)
        self.networkService = BaseNetworkService(analytics: analytics)
        self.universalLinkService = UniversalLinkService(analytics: analytics)
        self.tokenGroupIdentifier = TokenGroupIdentifier.identifier(tokenJsonUrl: R.file.tokensJson()!)!

        self.blockchainsProvider = BlockchainsProvider(
                serversProvider: serversProvider,
                blockchainFactory: BaseBlockchainFactory(
                    config: config,
                    analytics: analytics))

        self.assetDefinitionStore = AssetDefinitionStore(
            baseTokenScriptFiles: TokenScript.baseTokenScriptFiles,
            networkService: networkService,
            blockchainsProvider: blockchainsProvider)

        self.coinTickersFetcher = CoinTickersFetcherImpl(
            transporter: BaseApiTransporter(),
            analytics: analytics)

        self.restartHandler = RestartQueueHandler(
            serversProvider: serversProvider,
            restartQueue: RestartTaskQueue())

        self.tokenSwapper = TokenSwapper(
            reachabilityManager: reachability,
            serversProvider: serversProvider,
            networking: LiQuestTokenSwapperNetworking(networkService: networkService),
            analyticsLogger: analytics)

        self.tokenActionsService = TokenActionsService.instance(
            networkService: networkService,
            tokenSwapper: tokenSwapper)

        self.tokenImageFetcher = TokenImageFetcherImpl.instance(tokenGroupIdentifier: tokenGroupIdentifier)

        self.promptBackup = PromptBackup(
            keystore: keystore,
            config: config,
            analytics: analytics,
            walletBalanceProvidable: walletBalanceService)

        let blockchainProviderForResolvingEns = RpcBlockchainProvider(
            server: .forResolvingEns,
            analytics: analytics,
            params: .defaultParams(for: .forResolvingEns))

        self.blockiesGenerator = BlockiesGenerator(
            assetImageProvider: OpenSea(analytics: analytics, server: .main, config: config),
            storage: RealmStore.shared,
            blockchainProvider: blockchainProviderForResolvingEns)

        self.domainResolutionService = DomainResolutionService(
            blockiesGenerator: blockiesGenerator,
            storage: RealmStore.shared,
            networkService: networkService,
            blockchainProvider: blockchainProviderForResolvingEns)

        self.mediaContentDownloader = MediaContentDownloader.instance(reachability: reachability)
        self.notificationService = NotificationService.instance(walletBalanceService: walletBalanceService)

        self.walletConnectProvider = WalletConnectProvider.instance(
            serversProvider: serversProvider,
            keystore: keystore,
            dependencies: dependencies,
            config: config,
            caip10AccountProvidable: caip10AccountProvidable)

        self.analytics = analytics
        self.keystore = keystore
        self.securedStorage = securedStorage
        self.legacyFileBasedKeystore = legacyFileBasedKeystore

        self.shortcutHandler = ShortcutHandler()
        self.launchOptionsService = LaunchOptionsService(handlers: [
            shortcutHandler
        ])

        let donationUserActivityHandler = DonationUserActivityHandler(analytics: analytics)
        self.userActivityService = UserActivityService(handlers: [
            donationUserActivityHandler
        ])

        bindWalletAddressesStore()
        handleTokenScriptOverrideImport()
        restartHandler.navigation = self

        shortcutHandler.delegate = self
        donationUserActivityHandler.delegate = self
    }

    private func handleTokenScriptOverrideImport() {
        tokenScriptOverridesFileManager
            .importTokenScriptOverridesFileEvent
            .sink { [weak self] event in
                guard let strongSelf = self, let wallet = strongSelf.keystore.currentWallet else { return }

                switch event {
                case .failure(let error):
                    strongSelf.navigation?.show(error: error)
                case .success(let override):
                    guard let dep = strongSelf.walletDependencies(walletAddress: wallet.address) else { return }
                    guard let session = dep.sessionsProvider.session(for: override.server) else { return }
                    session.importToken.importToken(for: override.contract, onlyIfThereIsABalance: false)
                        .sinkAsync(receiveCompletion: { result in
                            guard case .failure(let error) = result else { return }
                            debugLog("Error while adding imported token contract: \(override.contract.eip55String) server: \(override.server) wallet: \(wallet.address.eip55String) error: \(error)")
                        })
                    if !override.destinationFileInUse {
                        strongSelf.navigation?.showTokenScriptFileImported(filename: override.filename)
                    }
                }
            }.store(in: &cancelable)
    }

    func handle(url: DeepLink) {
        switch url {
        case .maybeFileUrl(let url):
            tokenScriptOverridesFileManager.importTokenScriptOverrides(url: url)
        case .eip681(let url):
            guard let wallet = keystore.currentWallet, let dependency = walletDependencies(walletAddress: wallet.address) else { return }

            let paymentFlowResolver = Eip681UrlResolver(
                sessionsProvider: dependency.sessionsProvider,
                missingRPCServerStrategy: .fallbackToAnyMatching)

            paymentFlowResolver.resolve(url: url)
                .sinkAsync(receiveCompletion: { result in
                    guard case .failure(let error) = result else { return }
                    verboseLog("[Eip681UrlResolver] failure to resolve value from: \(url) with error: \(error)")
                }, receiveValue: { result in
                    switch result {
                    case .address:
                        break //Add handling address, maybe same action when scan qr code
                    case .transaction(let transactionType, let token):
                        self.navigation?.showPaymentFlow(for: .send(type: .transaction(transactionType)), server: token.server)
                    }
                })
        case .walletConnect(let url, let source):
            switch source {
            case .safariExtension:
                analytics.log(action: Analytics.Action.tapSafariExtensionRewrittenUrl, properties: [
                    Analytics.Properties.type.rawValue: "walletConnect"
                ])
            case .mobileLinking:
                break
            }
            navigation?.openWalletConnectSession(url: url)
        case .embeddedUrl(_, let url):
            navigation?.openUrlInDappBrowser(url: url, animated: true)
        case .shareContentAction(let action):
            switch action {
            case .string, .openApp:
                break //NOTE: here we can add parsing Addresses from string
            case .url(let url):
                navigation?.openUrlInDappBrowser(url: url, animated: true)
            }
        case .magicLink(_, let server, let url):
            guard let wallet = keystore.currentWallet, let dependency = walletDependencies(walletAddress: wallet.address) else { return }

            if let session = dependency.sessionsProvider.session(for: server) {
                navigation?.showImportMagicLink(session: session, url: url)
            } else {
                navigation?.showServerUnavailable(server: server)
            }
        case .walletApi(let action):
            navigation?.showWalletApi(action: action)
        }
    }

    private func bindWalletAddressesStore() {
        keystore.didRemoveWallet
            .sink { [serversProvider, legacyFileBasedKeystore, promptBackup] account in

                //TODO: pass ref
                FileWalletStorage().addOrUpdate(name: nil, for: account.address)
                promptBackup.deleteWallet(wallet: account)
                //TODO: make same as WalletConfig
                TransactionsTracker.resetFetchingState(account: account, serversProvider: serversProvider)
                Erc1155TokenIdsFetcher.deleteForWallet(account.address)
                DatabaseMigration.addToDeleteList(address: account.address)
                legacyFileBasedKeystore.delete(wallet: account)
                WalletConfig(address: account.address).clear()
                self.destroy(for: account)
            }.store(in: &cancelable)

        keystore.didAddWallet
            .sink { [promptBackup] in
                switch $0.event {
                case .new, .watch, .hardware:
                    break
                case .keystore, .mnemonic, .privateKey:
                    promptBackup.markWalletAsImported(wallet: $0.wallet)
                }
            }.store(in: &cancelable)

        keystore.walletsPublisher
            .receive(on: RunLoop.main) //NOTE: async to avoid `swift_beginAccess` crash
            .map { wallets -> [Wallet: WalletBalanceFetcherType] in
                var fetchers: [Wallet: WalletBalanceFetcherType] = [:]

                for wallet in wallets {
                    let dep = self.buildDependencies(for: wallet)
                    fetchers[wallet] = dep.fetcher
                }

                return fetchers
            }.sink { [walletBalanceService] in walletBalanceService.start(fetchers: $0) }
            .store(in: &cancelable)
    }

    func start(launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
        if AlphaWallet.Device.isSimulator {
            //Want to start as soon as possible
            TrackApiCalls.shared.start()

            UserDefaults.standard.set(!isRunningTests(), forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        }

        DatabaseMigration.dropDeletedRealmFiles(excluding: keystore.wallets)
        initializers()
        runServices()
        appTracker.start()
        notificationService.registerForReceivingRemoteNotifications()
        tokenScriptOverridesFileManager.start()
        migrateToStoringRawPrivateKeysInKeychain()
        tokenActionsService.start()

        handle(launchOptions: launchOptions)
    }

    private func handle(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard let launchOptions = launchOptions else { return }
        Task { await launchOptionsService.handle(launchOptions: launchOptions) }
    }

    deinit {
        tokenScriptOverridesFileManager.stop()
    }

    func applicationPerformActionFor(_ shortcutItem: UIApplicationShortcutItem) async -> Bool {
        return await shortcutHandler.handle(shortcutItem: shortcutItem)
    }

    func applicationDidBecomeActive() {
        handleUniversalLinkInPasteboard()
    }

    func applicationShouldAllowExtensionPointIdentifier(_ extensionPointIdentifier: UIApplication.ExtensionPointIdentifier) -> Bool {
        if extensionPointIdentifier == .keyboard {
            return false
        }
        return true
    }

    func applicationOpenUrl(_ url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return handleUniversalLink(url: url, source: .customUrlScheme)
    }

    func applicationContinueUserActivity(_ userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        let hasHandledIntent = userActivityService.handle(userActivity, restorationHandler: restorationHandler)
        if hasHandledIntent {
            return true
        }

        var handled = false
        if let url = userActivity.webpageURL {
            handled = handleUniversalLink(url: url, source: .deeplink)
        }
        //TODO: if we handle other types of URLs, check if handled==false, then we pass the url to another handlers
        return handled
    }

    private func migrateToStoringRawPrivateKeysInKeychain() {
        legacyFileBasedKeystore.migrateKeystoreFilesToRawPrivateKeysInKeychain(using: keystore)
    }

    private func initializers() {
        let initializers: [Initializer] = [
            ConfigureImageStorage(),
            ConfigureApp(),
            CleanupWallets(keystore: keystore, config: config),
            SkipBackupFiles(legacyFileBasedKeystore: legacyFileBasedKeystore),
            CleanupPasscode(keystore: keystore, lock: lock),
            KeyboardInitializer(),
            DatabasePathLog(),
            TickerIdsMatchLog()
        ]

        initializers.forEach { $0.perform() }
    }

    private func runServices() {
        services = [
            ReportUsersWalletAddresses(keystore: keystore),
            ReportUsersActiveChains(serversProvider: serversProvider),
            MigrateToSupportEip1559Transactions(
                serversProvider: serversProvider,
                keychain: keystore)
        ]
        services.forEach { $0.perform() }
    }

    /// Return true if handled
    @discardableResult func handleUniversalLink(url: URL, source: UrlSource) -> Bool {
        keystore.createWalletIfMissing()
            .sink(receiveValue: { _ in self.navigation?.showActiveWalletIfNeeded() })
            .store(in: &cancelable)

        return universalLinkService.handleUniversalLink(url: url, source: source)
    }

    func handleUniversalLinkInPasteboard() {
        universalLinkService.handleUniversalLinkInPasteboard()
    }

    func launchUniversalScannerFromQuickAction() {
        launchUniversalScanner(fromSource: .quickAction)
    }

    func launchUniversalScanner(fromSource source: Analytics.ScanQRCodeSource) {
        navigation?.showActiveWalletIfNeeded()
        navigation?.launchUniversalScanner(fromSource: source)
    }

    func buildDependencies(for wallet: Wallet) -> WalletDependencies {
        if let dep = dependencies[wallet] { return dep  }

        let tokensDataStore: TokensDataStore = MultipleChainsTokensDataStore(store: .storage(for: wallet))
        let eventsDataStore: NonActivityEventsDataStore = NonActivityMultiChainEventsDataStore(store: .storage(for: wallet))
        let transactionsDataStore: TransactionDataStore = TransactionDataStore(store: .storage(for: wallet))
        let eventsActivityDataStore: EventsActivityDataStoreProtocol = EventsActivityDataStore(store: .storage(for: wallet))

        let sessionsProvider = BaseSessionsProvider(
            config: config,
            analytics: analytics,
            blockchainsProvider: blockchainsProvider,
            tokensDataStore: tokensDataStore,
            eventsDataStore: eventsDataStore,
            assetDefinitionStore: assetDefinitionStore,
            reachability: reachability,
            wallet: wallet,
            apiTransporterFactory: apiTransporterFactory)

        sessionsProvider.start()

        let tokensService = AlphaWalletTokensService(
            sessionsProvider: sessionsProvider,
            tokensDataStore: tokensDataStore,
            analytics: analytics,
            transactionsStorage: transactionsDataStore,
            assetDefinitionStore: assetDefinitionStore,
            transporter: BaseApiTransporter())

        let tokensPipeline: TokensProcessingPipeline = WalletDataProcessingPipeline(
            wallet: wallet,
            tokensService: tokensService,
            coinTickersFetcher: coinTickersFetcher,
            assetDefinitionStore: assetDefinitionStore,
            eventsDataStore: eventsDataStore,
            currencyService: currencyService,
            sessionsProvider: sessionsProvider)

        tokensPipeline.start()

        let fetcher = WalletBalanceFetcher(
            wallet: wallet,
            tokensPipeline: tokensPipeline,
            currencyService: currencyService,
            tokensService: tokensService)

        fetcher.start()

        let activitiesPipeLine = ActivitiesPipeLine(
            config: config,
            wallet: wallet,
            assetDefinitionStore: assetDefinitionStore,
            transactionDataStore: transactionsDataStore,
            tokensService: tokensService,
            sessionsProvider: sessionsProvider,
            eventsActivityDataStore: eventsActivityDataStore,
            eventsDataStore: eventsDataStore)

        let transactionsService = TransactionsService(
            sessionsProvider: sessionsProvider,
            transactionDataStore: transactionsDataStore,
            analytics: analytics,
            tokensService: tokensService,
            networkService: networkService,
            config: config,
            assetDefinitionStore: assetDefinitionStore)

        let dependency = WalletDependencies(
            activitiesPipeLine: activitiesPipeLine,
            transactionsDataStore: transactionsDataStore,
            tokensDataStore: tokensDataStore,
            tokensService: tokensService,
            pipeline: tokensPipeline,
            fetcher: fetcher,
            sessionsProvider: sessionsProvider,
            eventsDataStore: eventsDataStore,
            transactionsService: transactionsService)

        dependencies[wallet] = dependency

        return dependency
    }

    private func destroy(for wallet: Wallet) {
        dependencies.removeValue(forKey: wallet)
    }

    func walletDependencies(walletAddress: AlphaWallet.Address) -> WalletDependencies? {
        guard let wallet = dependencies.values.keys.first(where: { $0.address == walletAddress }) else { return nil }
        return dependencies[wallet]
    }
}
// swiftlint:enable type_body_length

extension Application: RestartQueueNavigatable {
    func didLoadUrlInDappBrowser(url: URL, in handler: RestartQueueHandler) {
        navigation?.openUrlInDappBrowser(url: url, animated: false)
    }
}

extension Application: DonationUserActivityHandlerDelegate {
    func showQrCode() {
        navigation?.showQrCode()
    }
}

extension Application: ShortcutLaunchOptionsHandlerDelegate { }

extension AtomicDictionary: WalletDependenciesProvidable where Key == Wallet, Value == WalletDependencies {
    public func walletDependencies(walletAddress: AlphaWallet.Address) -> WalletDependencies? {
        guard let wallet = values.keys.first(where: { $0.address == walletAddress }) else { return nil }
        return self[wallet]
    }
}

extension NotificationService {
    static func instance(walletBalanceService: WalletBalanceService) -> NotificationService {
        NotificationService(
            sources: [],
            walletBalanceService: walletBalanceService,
            notificationService: LocalNotificationService(),
            pushNotificationsService: UNUserNotificationsService())
    }
}

extension TokenImageFetcherImpl {
    static func instance(tokenGroupIdentifier: TokenGroupIdentifierProtocol) -> TokenImageFetcherImpl {
        TokenImageFetcherImpl(
            networking: KingfisherImageFetcher(),
            tokenGroupIdentifier: tokenGroupIdentifier,
            spamImage: R.image.spamSmall()!)
    }
}
