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
import AlphaWalletNotifications
import AlphaWalletTokenScript

extension TokenScript {
    static let baseTokenScriptFiles: [TokenType: String] = [
        .erc20: (try! String(contentsOf: R.file.erc20TokenScriptTsml()!)),
        .erc721: (try! String(contentsOf: R.file.erc721TokenScriptTsml()!)),
    ]
}

protocol ApplicationNavigatable: RestartQueueNavigatable, DonationUserActivityNavigatable, UniversalLinkNavigatable, SystemSettingsRequestable, PushNotificationNavigatable {
    var navigation: AnyPublisher<ApplicationNavigation, Never> { get }

    func showCreateWallet()
    func showActiveWallet(wallet: Wallet)
    func showActiveWalletIfNeeded()
    func show(error: Error)
}

// swiftlint:disable type_body_length
class Application: WalletDependenciesProvidable {
    private var services: [Service] = []
    private let dependencies: AtomicDictionary<Wallet, WalletDependencies> = .init()
    private var cancelable = Set<AnyCancellable>()
    private let launchOptionsService: LaunchOptionsService
    private let userActivityService: UserActivityService
    private let shortcutHandler: ShortcutHandler
    private let navigationSubject: CurrentValueSubject<ApplicationNavigation, Never> = .init(.onboarding)
    private var navigationCancellable: Cancellable?
    private let donationUserActivityHandler: DonationUserActivityHandler
    private let systemSettingsRequestableDelegate: SystemSettingsRequestableDelegate
    private let notificationHandler: NotificationHandler

    let config: Config
    let legacyFileBasedKeystore: LegacyFileBasedKeystore
    let lock: Lock
    let keystore: Keystore
    //This exist because feature flags are set at the app level (as of 20230709: AlpahWalletFoundation), but we read a few of those flags within AlphaWalletTokenScript
    let tokenScriptFeatures: TokenScriptFeatures
    let assetDefinitionStore: AssetDefinitionStore
    let appTracker: AppTracker
    let universalLinkService: UniversalLinkService
    let analytics: AnalyticsServiceType
    let restartHandler: RestartQueueHandler
    let currencyService: CurrencyService
    let coinTickers: CoinTickersProvider & CoinTickersFetcher
    let walletBalanceService: WalletBalanceService & WalletBalanceProvidable
    let networkService: NetworkService
    let tokenSwapper: TokenSwapper
    let tokenActionsService: TokenActionsService
    let serversProvider: ServersProvidable
    let caip10AccountProvidable: CAIP10AccountProvidable
    let walletConnectProvider: WalletConnectProvider
    let blockiesGenerator: BlockiesGenerator
    let domainResolutionService: DomainNameResolutionServiceType
    let localNotificationsService: LocalNotificationService
    let pushNotificationsService: PushNotificationsService
    let blockchainsProvider: BlockchainsProvider
    let reachability = ReachabilityManager()
    let securedStorage: SecuredPasswordStorage & SecuredStorage
    let tokenScriptOverridesFileManager = TokenScriptOverridesFileManager()
    let apiTransporterFactory = ApiTransporterFactory()
    let tokenImageFetcher: TokenImageFetcher
    let tokenGroupIdentifier: TokenGroupIdentifierProtocol
    let promptBackup: PromptBackup
    let mediaContentDownloader: MediaContentDownloader

    weak var navigation: ApplicationNavigatable? { didSet { didSetNavigation() } }

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

    // swiftlint:disable function_body_length
    init(analytics: AnalyticsServiceType,
         keystore: Keystore,
         securedStorage: SecuredPasswordStorage & SecuredStorage,
         legacyFileBasedKeystore: LegacyFileBasedKeystore,
         config: Config = Config()) {

        self.config = config
        let addressStorage = FileAddressStorage()
        AlphaWalletAddress.register(addressStorage: addressStorage)

        self.appTracker = AppTracker()
        self.lock = SecuredLock(securedStorage: securedStorage)
        self.serversProvider = BaseServersProvider(config: config)
        self.caip10AccountProvidable = AnyCAIP10AccountProvidable(keystore: keystore, serversProvidable: serversProvider)
        self.currencyService = CurrencyService(storage: config)
        self.walletBalanceService = MultiWalletBalanceService(currencyService: currencyService)
        self.networkService = BaseNetworkService()
        let navigationHandler = ApplicationNavigationHandler(subject: navigationSubject)
        self.universalLinkService = BaseUniversalLinkService(
            analytics: analytics,
            tokenScriptOverridesFileManager: tokenScriptOverridesFileManager,
            dependencies: dependencies,
            keystore: keystore,
            navigationHandler: navigationHandler)

        self.tokenGroupIdentifier = TokenGroupIdentifier.identifier(tokenJsonUrl: R.file.tokensJson()!)!
        self.systemSettingsRequestableDelegate = SystemSettingsRequestableDelegate()
        self.blockchainsProvider = BlockchainsProviderImplementation(
                serversProvider: serversProvider,
                blockchainFactory: BaseBlockchainFactory(analytics: analytics))
        let tokenScriptFeatures = TokenScriptFeatures()
        Self.copyFeatures(Features.current, toTokenScriptFeatures: tokenScriptFeatures)
        self.tokenScriptFeatures = tokenScriptFeatures
        self.assetDefinitionStore = AssetDefinitionStore(baseTokenScriptFiles: TokenScript.baseTokenScriptFiles, networkService: networkService, blockchainsProvider: blockchainsProvider, features: tokenScriptFeatures)

        self.coinTickers = CoinTickers(
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

        let blockchainProviderForResolvingEns = RpcBlockchainProvider.instanceForResolvingEns(analytics: analytics)

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
        self.localNotificationsService = LocalNotificationService.instance()
        self.notificationHandler = AlphaWalletNotificationHandler.instance(
            dependencies: dependencies,
            navigationHandler: navigationHandler,
            keystore: keystore)
        self.pushNotificationsService = BasePushNotificationsService.instance(
            keystore: keystore,
            notificationHandler: notificationHandler,
            systemSettingsRequestable: systemSettingsRequestableDelegate)

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
            shortcutHandler,
            PushNotificationLaunchOptionsHandler(pushNotificationsService: pushNotificationsService)
        ])

        self.donationUserActivityHandler = DonationUserActivityHandler(analytics: analytics)
        self.userActivityService = UserActivityService(handlers: [
            donationUserActivityHandler
        ])

        Features.delegate = self

        bindWalletAddressesStore()
        handleTokenScriptOverrideImport()
    }
    // swiftlint:enable function_body_length

    //NOTE: subscribe for navigation state to keep its state in app
    private func didSetNavigation() {
        navigationCancellable?.cancel()
        guard let nav = navigation else { return }

        restartHandler.navigation = nav
        donationUserActivityHandler.navigation = nav
        shortcutHandler.navigation = self
        universalLinkService.navigation = nav
        systemSettingsRequestableDelegate.delegate = nav
        notificationHandler.navigation = nav
        navigationCancellable = nav.navigation
            .multicast(subject: navigationSubject)
            .connect()
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

    private func bindWalletAddressesStore() {
        keystore.didRemoveWallet
            .sink { [serversProvider, legacyFileBasedKeystore, promptBackup] account in

                //TODO: pass ref
                FileWalletStorage().addOrUpdate(name: nil, for: account.address)
                promptBackup.deleteWallet(wallet: account)
                //TODO: make same as WalletConfig
                PersistantSchedulerStateProvider.resetFetchingState(account: account, servers: serversProvider.allServers)
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
        pushNotificationsService.requestToEnableNotification()
        tokenScriptOverridesFileManager.start()
        migrateToStoringRawPrivateKeysInKeychain()
        tokenActionsService.start()

        if let wallet = keystore.currentWallet, keystore.hasWallets {
            navigation?.showActiveWallet(wallet: wallet)
        } else {
            navigation?.showCreateWallet()
        }

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
        ]

        initializers.forEach { $0.perform() }
    }

    private func runServices() {
        services = [
            TickerIdsMatchLog(),
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

    func launchUniversalScannerFromQuickAction() {
        showUniversalScanner(fromSource: .quickAction)
    }

    func showUniversalScanner(fromSource source: Analytics.ScanQRCodeSource) {
        navigation?.showActiveWalletIfNeeded()
        navigation?.showUniversalScanner(fromSource: source)
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
            coinTickersFetcher: coinTickers,
            coinTickersProvider: coinTickers,
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

    private static func copyFeatures(_ features: Features, toTokenScriptFeatures tokenScriptFeatures: TokenScriptFeatures) {
        tokenScriptFeatures.isActivityEnabled = features.isAvailable(.isActivityEnabled)
        tokenScriptFeatures.isTokenScriptSignatureStatusEnabled = features.isAvailable(.isTokenScriptSignatureStatusEnabled)
        tokenScriptFeatures.shouldLoadTokenScriptWithFailedSignatures = features.isAvailable(.shouldLoadTokenScriptWithFailedSignatures )
    }
}
// swiftlint:enable type_body_length

extension Application: WalletApiCoordinatorDelegate {
    func didOpenUrl(in service: WalletApiCoordinator, redirectUrl: URL) {
        if UIApplication.shared.canOpenURL(redirectUrl) {
            UIApplication.shared.open(redirectUrl)
        } else {
            navigation?.openUrlInDappBrowser(url: redirectUrl, animated: true)
        }
    }

    private class SystemSettingsRequestableDelegate: SystemSettingsRequestable {
        weak var delegate: SystemSettingsRequestable?

        @MainActor func promptOpenSettings() async -> Result<Void, Error> {
            struct NoDelegateError: Error {}
            guard let delegate = delegate else { return .failure(NoDelegateError()) }
            return await delegate.promptOpenSettings()
        }
    }
}

extension Application: ShortcutNavigatable { }

extension Application: FeaturesDelegate {
    func featuresModified(_ features: Features) {
        Self.copyFeatures(features, toTokenScriptFeatures: tokenScriptFeatures)
    }
}

extension AtomicDictionary: WalletDependenciesProvidable where Key == Wallet, Value == WalletDependencies {
    public func walletDependencies(walletAddress: AlphaWallet.Address) -> WalletDependencies? {
        guard let wallet = values.keys.first(where: { $0.address == walletAddress }) else { return nil }
        return self[wallet]
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

extension RpcBlockchainProvider {
    static func instanceForResolvingEns(analytics: AnalyticsLogger) -> RpcBlockchainProvider {
        return RpcBlockchainProvider(
            server: .forResolvingDomainNames,
            analytics: analytics,
            params: .defaultParams(for: .forResolvingDomainNames))
    }
}

extension LocalNotificationService {
    static func instance() -> LocalNotificationService {
        let deliveryService = DefaultLocalNotificationDeliveryService(notificationCenter: .current())
        return LocalNotificationService(
            sources: [],
            deliveryService: deliveryService)
    }
}

extension AlphaWalletNotificationHandler {
    static func instance(dependencies: WalletDependenciesProvidable,
                         navigationHandler: ApplicationNavigationHandler,
                         keystore: Keystore) -> NotificationHandler {

        return AlphaWalletNotificationHandler(
            application: .shared,
            notificationCenter: .default,
            walletsDependencies: dependencies,
            navigationHandler: navigationHandler,
            keystore: keystore)
    }
}

extension BasePushNotificationsService {
    static func instance(keystore: Keystore,
                         notificationHandler: NotificationHandler,
                         systemSettingsRequestable: SystemSettingsRequestable) -> PushNotificationsService {

        let unUserNotificationService = UNUserNotificationsService(
            application: .shared,
            systemSettingsRequestable: systemSettingsRequestable)

        return BasePushNotificationsService(
            unUserNotificationService: unUserNotificationService,
            keystore: keystore,
            networking: BasePushNotificationsNetworking(
                transporter: BaseApiTransporter(),
                apiKey: Constants.Credentials.notificationsApiKey),
            notificationHandler: notificationHandler,
            isSubscribedStorage: BaseNotificationSubscribersStorage(defaults: .standard))
    }
}
