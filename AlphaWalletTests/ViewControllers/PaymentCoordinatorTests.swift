// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import Combine

func sessions(server: RPCServer = .main) -> CurrentValueSubject<ServerDictionary<WalletSession>, Never> {
    return CurrentValueSubject<ServerDictionary<WalletSession>, Never>(.make(server: server))
}

extension TokensFilter {
    static func make() -> TokensFilter {
        let actionsService = TokenActionsService()
        return TokensFilter(assetDefinitionStore: .init(), tokenActionsService: actionsService, coinTickersFetcher: CoinGeckoTickersFetcher.make(), tokenGroupIdentifier: FakeTokenGroupIdentifier())
    }
}

extension WalletDataProcessingPipeline {
    static func make(wallet: Wallet = .make(), server: RPCServer = .main) -> WalletDependency {
        let fas = FakeAnalyticsService()
        let sessionsProvider: SessionsProvider = .make(wallet: wallet, servers: [server])

        let tokensDataStore = FakeTokensDataStore(account: wallet, servers: [server])
        let importToken = ImportToken(sessionProvider: sessionsProvider, wallet: wallet, tokensDataStore: tokensDataStore, assetDefinitionStore: .init(), analytics: fas)
        let eventsDataStore = FakeEventsDataStore()
        let transactionsStorage = FakeTransactionsStorage()
        let nftProvider = FakeNftProvider()
        let coinTickersFetcher = CoinGeckoTickersFetcher.make()

        let tokensService: TokensService = AlphaWalletTokensService(sessionsProvider: sessionsProvider, tokensDataStore: tokensDataStore, analytics: fas, importToken: importToken, transactionsStorage: transactionsStorage, nftProvider: nftProvider, assetDefinitionStore: .init())

        let pipeline: TokensProcessingPipeline = WalletDataProcessingPipeline(wallet: wallet, tokensService: tokensService, coinTickersFetcher: coinTickersFetcher, assetDefinitionStore: .init(), eventsDataStore: eventsDataStore)
        pipeline.start()

        let fetcher = WalletBalanceFetcher(wallet: wallet, service: pipeline)

        return FakeWalletDep(tokensDataStore: tokensDataStore, transactionsStorage: transactionsStorage, importToken: importToken, tokensService: tokensService, pipeline: pipeline, fetcher: fetcher, sessionsProvider: sessionsProvider)
    }

    struct FakeWalletDep: WalletDependency {
        let tokensDataStore: TokensDataStore
        let transactionsStorage: TransactionDataStore
        let importToken: ImportToken
        let tokensService: TokensService
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
