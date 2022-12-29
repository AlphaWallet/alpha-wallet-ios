// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import Combine
import AlphaWalletFoundation

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
    static func make(wallet: Wallet = .make(), server: RPCServer = .main) -> FakeWalletDep {
        let fas = FakeAnalyticsService()
        let sessionsProvider: SessionsProvider = .make(wallet: wallet, servers: [server])
        let eventsActivityDataStore: EventsActivityDataStoreProtocol = EventsActivityDataStore(store: .fake(for: wallet))

        let tokensDataStore = FakeTokensDataStore(account: wallet, servers: [server])
        let contractDataFetcher = FakeContractDataFetcher()
        let importToken = ImportToken.make(tokensDataStore: tokensDataStore, contractDataFetcher: contractDataFetcher)
        let eventsDataStore = FakeEventsDataStore()
        let transactionsDataStore = FakeTransactionsStorage()
        let nftProvider = FakeNftProvider()
        let coinTickersFetcher = CoinTickersFetcherImpl.make()
        let currencyService: CurrencyService = .make()

        let tokensService = AlphaWalletTokensService(
            sessionsProvider: sessionsProvider,
            tokensDataStore: tokensDataStore,
            analytics: fas,
            importToken: importToken,
            transactionsStorage: transactionsDataStore,
            nftProvider: nftProvider,
            assetDefinitionStore: .make(),
            networkService: FakeNetworkService())

        let pipeline: TokensProcessingPipeline = WalletDataProcessingPipeline(
            wallet: wallet,
            tokensService: tokensService,
            coinTickersFetcher: coinTickersFetcher,
            assetDefinitionStore: .make(),
            eventsDataStore: eventsDataStore,
            currencyService: currencyService)

        let fetcher = WalletBalanceFetcher(wallet: wallet, tokensService: pipeline)

        let activitiesPipeLine = ActivitiesPipeLine(
            config: .make(),
            wallet: wallet,
            assetDefinitionStore: .make(),
            transactionDataStore: transactionsDataStore,
            tokensService: tokensService,
            sessionsProvider: sessionsProvider,
            eventsActivityDataStore: eventsActivityDataStore,
            eventsDataStore: eventsDataStore,
            analytics: fas)

        let dep = FakeWalletDep(
            activitiesPipeLine: activitiesPipeLine,
            tokensDataStore: tokensDataStore,
            transactionsDataStore: transactionsDataStore,
            importToken: importToken,
            tokensService: tokensService,
            pipeline: pipeline,
            fetcher: fetcher,
            sessionsProvider: sessionsProvider,
            currencyService: currencyService)
        
        dep.sessionsProvider.start(wallet: wallet)
        dep.fetcher.start()
        dep.pipeline.start()

        return dep
    }

    struct FakeWalletDep {
        let activitiesPipeLine: ActivitiesPipeLine
        let tokensDataStore: TokensDataStore
        let transactionsDataStore: TransactionDataStore
        let importToken: ImportToken
        let tokensService: DetectedContractsProvideble & TokenProvidable & TokenAddable & TokensServiceTests
        let pipeline: TokensProcessingPipeline
        let fetcher: WalletBalanceFetcher
        let sessionsProvider: SessionsProvider
        let currencyService: AlphaWalletFoundation.CurrencyService
    }

}

extension SessionsProvider {
    static func make(wallet: Wallet = .make(), servers: [RPCServer] = [.main]) -> SessionsProvider {
        let provider = FakeSessionsProvider(servers: servers)
        provider.start(wallet: wallet)

        return provider
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
            sessionProvider: dep.sessionsProvider,
            keystore: FakeEtherKeystore(),
            assetDefinitionStore: .make(),
            analytics: FakeAnalyticsService(),
            tokenCollection: dep.pipeline,
            domainResolutionService: FakeDomainResolutionService(),
            tokenSwapper: FakeTokenSwapper(),
            tokensFilter: .make(),
            importToken: dep.importToken,
            networkService: FakeNetworkService())
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
            sessionProvider: dep.sessionsProvider,
            keystore: FakeEtherKeystore(),
            assetDefinitionStore: .make(),
            analytics: FakeAnalyticsService(),
            tokenCollection: dep.pipeline,
            domainResolutionService: FakeDomainResolutionService(),
            tokenSwapper: FakeTokenSwapper(),
            tokensFilter: .make(),
            importToken: dep.importToken,
            networkService: FakeNetworkService())

        coordinator.start()

        XCTAssertEqual(1, coordinator.coordinators.count)
        XCTAssertTrue(coordinator.coordinators.first is RequestCoordinator)
    }
}
