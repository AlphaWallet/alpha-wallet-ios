// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import Combine
import AlphaWalletFoundation
import AlphaWalletWeb3

extension TokensFilter {
    static func make() -> TokensFilter {
        let actionsService = TokenActionsService()
        return TokensFilter(tokenActionsService: actionsService, tokenGroupIdentifier: FakeTokenGroupIdentifier())
    }
}

extension RealmStore {
    static func fake(for wallet: Wallet) -> RealmStore {
        RealmStore(realm: fakeRealm(wallet: wallet), name: RealmStore.threadName(for: wallet))
    }
}
extension CurrencyService {
    static func make() -> CurrencyService {
        return .init(storage: Config())
    }
}

extension WalletDataProcessingPipeline {
    static func make(wallet: Wallet = .make(),
                     server: RPCServer = .main,
                     coinTickersFetcher: CoinTickersProvider & CoinTickersFetcher = CoinTickers.make(),
                     currencyService: CurrencyService = .make()) -> WalletDependencies {
        let fas = FakeAnalyticsService()

        let tokensDataStore = FakeTokensDataStore(account: wallet, servers: [server])
        let sessionsProvider = FakeSessionsProvider(
            config: .make(),
            analytics: FakeAnalyticsService(),
            blockchainsProvider: BlockchainsProviderImplementation .make(servers: [server]),
            tokensDataStore: tokensDataStore,
            assetDefinitionStore: .make(),
            reachability: FakeReachabilityManager(true),
            wallet: wallet,
            eventsDataStore: FakeEventsDataStore(account: wallet))

        sessionsProvider.start()

        let eventsActivityDataStore: EventsActivityDataStoreProtocol = EventsActivityDataStore(store: .fake(for: wallet))

        let eventsDataStore = FakeEventsDataStore()
        let transactionsDataStore = FakeTransactionsStorage()

        let tokensService = AlphaWalletTokensService(
            sessionsProvider: sessionsProvider,
            tokensDataStore: tokensDataStore,
            analytics: fas,
            transactionsStorage: transactionsDataStore,
            assetDefinitionStore: .make(),
            transporter: FakeApiTransporter())

        let pipeline: TokensProcessingPipeline = WalletDataProcessingPipeline(
            wallet: wallet,
            tokensService: tokensService,
            coinTickersFetcher: coinTickersFetcher,
            coinTickersProvider: coinTickersFetcher,
            assetDefinitionStore: .make(),
            eventsDataStore: eventsDataStore,
            currencyService: currencyService,
            sessionsProvider: sessionsProvider)

        let fetcher = WalletBalanceFetcher(
            wallet: wallet,
            tokensPipeline: pipeline,
            currencyService: .make(),
            tokensService: tokensService)

        let activitiesPipeLine = ActivitiesPipeLine(
            config: .make(),
            wallet: wallet,
            assetDefinitionStore: .make(),
            transactionDataStore: transactionsDataStore,
            tokensService: tokensService,
            sessionsProvider: sessionsProvider,
            eventsActivityDataStore: eventsActivityDataStore,
            eventsDataStore: eventsDataStore)

        let transactionsService = TransactionsService(
            sessionsProvider: sessionsProvider,
            transactionDataStore: transactionsDataStore,
            analytics: fas,
            tokensService: tokensService,
            networkService: FakeNetworkService(),
            config: .make(),
            assetDefinitionStore: .make())

        let dep = WalletDependencies(
            activitiesPipeLine: activitiesPipeLine,
            transactionsDataStore: transactionsDataStore,
            tokensDataStore: tokensDataStore,
            tokensService: tokensService,
            pipeline: pipeline,
            fetcher: fetcher,
            sessionsProvider: sessionsProvider,
            eventsDataStore: eventsDataStore,
            transactionsService: transactionsService)

        dep.sessionsProvider.start()
        dep.fetcher.start()
        dep.pipeline.start()

        return dep
    }
}

class PaymentCoordinatorTests: XCTestCase {

    func testSendFlow() {
        let address: AlphaWallet.Address = .make()

        let wallet: Wallet = .make()
        let server: RPCServer = .main
        let dep = WalletDataProcessingPipeline.make(wallet: wallet, server: server)

        let coordinator = PaymentCoordinator(
            navigationController: FakeNavigationController(),
            flow: .send(type: .transaction(.nativeCryptocurrency(Token(), destination: .init(address: address), amount: .notSet))),
            server: .main,
            sessionsProvider: dep.sessionsProvider,
            keystore: FakeEtherKeystore(),
            assetDefinitionStore: .make(),
            analytics: FakeAnalyticsService(),
            tokensPipeline: dep.pipeline,
            domainResolutionService: FakeDomainResolutionService(),
            tokenSwapper: TokenSwapper.make(),
            tokensFilter: .make(),
            networkService: FakeNetworkService(),
            transactionDataStore: FakeTransactionsStorage(wallet: wallet),
            tokenImageFetcher: FakeTokenImageFetcher(),
            tokensService: dep.tokensService)
        coordinator.start()

        XCTAssertEqual(1, coordinator.coordinators.count)
        XCTAssertTrue(coordinator.coordinators.first is SendCoordinator)
    }

    func testRequestFlow() {
        let wallet: Wallet = .make()
        let server: RPCServer = .main
        let dep = WalletDataProcessingPipeline.make(wallet: wallet, server: server)

        let coordinator = PaymentCoordinator(
            navigationController: FakeNavigationController(),
            flow: .request,
            server: .main,
            sessionsProvider: dep.sessionsProvider,
            keystore: FakeEtherKeystore(),
            assetDefinitionStore: .make(),
            analytics: FakeAnalyticsService(),
            tokensPipeline: dep.pipeline,
            domainResolutionService: FakeDomainResolutionService(),
            tokenSwapper: TokenSwapper.make(),
            tokensFilter: .make(),
            networkService: FakeNetworkService(),
            transactionDataStore: FakeTransactionsStorage(wallet: wallet),
            tokenImageFetcher: FakeTokenImageFetcher(),
            tokensService: dep.tokensService)

        coordinator.start()

        XCTAssertEqual(1, coordinator.coordinators.count)
        XCTAssertTrue(coordinator.coordinators.first is RequestCoordinator)
    }
}

import AlphaWalletOpenSea

class FakeTokenImageFetcher: TokenImageFetcher {

    func image(contractAddress: AlphaWallet.Address,
               server: RPCServer,
               name: String,
               type: TokenType,
               balance: NonFungibleFromJson?,
               size: GoogleContentSize,
               contractDefinedImage: UIImage?,
               colors: [UIColor],
               staticOverlayIcon: UIImage?,
               blockChainNameColor: UIColor,
               serverIconImage: UIImage?) -> TokenImagePublisher {
        return .empty()
    }
}
