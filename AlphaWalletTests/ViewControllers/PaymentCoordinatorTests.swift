// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import Combine
import AlphaWalletFoundation

extension TokensFilter {
    static func make() -> TokensFilter {
        let actionsService = TokenActionsService()
        return TokensFilter(assetDefinitionStore: .init(), tokenActionsService: actionsService, coinTickersFetcher: CoinGeckoTickersFetcher.make(), tokenGroupIdentifier: FakeTokenGroupIdentifier())
    }
}

extension RealmStore {
    static func fake(for wallet: Wallet) -> RealmStore {
        RealmStore(realm: fakeRealm(wallet: wallet), name: RealmStore.threadName(for: wallet))
    }
}

extension WalletDataProcessingPipeline {
    static func make(wallet: Wallet = .make(), server: RPCServer = .main) -> WalletDependency {
        let fas = FakeAnalyticsService()
        let sessionsProvider: SessionsProvider = .make(wallet: wallet, servers: [server])
        let store: RealmStore = .fake(for: wallet)
        let tokensDataStore = FakeTokensDataStore(account: wallet, servers: [server])
        let importToken = ImportToken(sessionProvider: sessionsProvider, wallet: wallet, tokensDataStore: tokensDataStore, assetDefinitionStore: .init(), analytics: fas)
        let eventsDataStore = FakeEventsDataStore()
        let transactionsDataStore = FakeTransactionsStorage()
        let nftProvider = FakeNftProvider()
        let coinTickersFetcher = CoinGeckoTickersFetcher.make()

        let tokensService = AlphaWalletTokensService(sessionsProvider: sessionsProvider, tokensDataStore: tokensDataStore, analytics: fas, importToken: importToken, transactionsStorage: transactionsDataStore, nftProvider: nftProvider, assetDefinitionStore: .init())

        let pipeline: TokensProcessingPipeline = WalletDataProcessingPipeline(wallet: wallet, tokensService: tokensService, coinTickersFetcher: coinTickersFetcher, assetDefinitionStore: .init(), eventsDataStore: eventsDataStore)

        let fetcher = WalletBalanceFetcher(wallet: wallet, tokensService: pipeline)

        let dep = FakeWalletDep(store: store, tokensDataStore: tokensDataStore, transactionsDataStore: transactionsDataStore, importToken: importToken, tokensService: tokensService, pipeline: pipeline, fetcher: fetcher, sessionsProvider: sessionsProvider)
        dep.sessionsProvider.start(wallet: wallet)
        dep.fetcher.start()
        dep.pipeline.start()

        return dep
    }

    struct FakeWalletDep: WalletDependency {
        let store: RealmStore
        let tokensDataStore: TokensDataStore
        let transactionsDataStore: TransactionDataStore
        let importToken: ImportToken
        let tokensService: DetectedContractsProvideble & TokenProvidable & TokenAddable & TokensServiceTests
        let pipeline: TokensProcessingPipeline
        let fetcher: WalletBalanceFetcher
        let sessionsProvider: SessionsProvider
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
            flow: .send(type: .transaction(.nativeCryptocurrency(Token(), destination: .init(address: address), amount: nil))),
            server: .main,
            sessionProvider: dep.sessionsProvider,
            keystore: FakeEtherKeystore(),
            assetDefinitionStore: AssetDefinitionStore(),
            analytics: FakeAnalyticsService(),
            tokenCollection: dep.pipeline,
            domainResolutionService: FakeDomainResolutionService(),
            tokenSwapper: FakeTokenSwapper(),
            tokensFilter: .make()
        )
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
            assetDefinitionStore: AssetDefinitionStore(),
            analytics: FakeAnalyticsService(),
            tokenCollection: dep.pipeline,
            domainResolutionService: FakeDomainResolutionService(),
            tokenSwapper: FakeTokenSwapper(),
            tokensFilter: .make()
        )

        coordinator.start()

        XCTAssertEqual(1, coordinator.coordinators.count)
        XCTAssertTrue(coordinator.coordinators.first is RequestCoordinator)
    }
}
