// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import Combine
import AlphaWalletFoundation

final class FakeSwapTokenService: TokenActionsService {
}

extension PromptBackupCoordinator {
    static func make(wallet: Wallet = .make()) -> PromptBackupCoordinator {
        PromptBackupCoordinator(
            wallet: wallet,
            promptBackup: .make(),
            keystore: FakeEtherKeystore(),
            analytics: FakeAnalyticsService())
    }
}
class TokensCoordinatorTests: XCTestCase {

    func testRootViewController() {
        let sessionsProvider = FakeSessionsProvider.make(servers: [.main])
        let config: Config = .make()
        let tokenActionsService = FakeSwapTokenService()
        let wallet: Wallet = .make()
        let dep = WalletDataProcessingPipeline.make(wallet: .make(), server: .main)

        let coordinator = TokensCoordinator(
            navigationController: FakeNavigationController(),
            sessionsProvider: sessionsProvider,
            keystore: FakeEtherKeystore(),
            config: config,
            assetDefinitionStore: .make(),
            promptBackupCoordinator: .make(wallet: wallet),
            analytics: FakeAnalyticsService(),
            tokenActionsService: tokenActionsService,
            walletConnectCoordinator: .fake(),
            coinTickersProvider: CoinTickers.make(),
            activitiesService: FakeActivitiesService(),
            walletBalanceService: FakeMultiWalletBalanceService(),
            tokenCollection: dep.pipeline,
            tokensService: dep.tokensService,
            blockiesGenerator: .make(),
            domainResolutionService: FakeDomainResolutionService(),
            tokensFilter: .make(),
            currencyService: .make(),
            tokenImageFetcher: FakeTokenImageFetcher(),
            serversProvider: BaseServersProvider())

        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is TokensViewController)
    }
}

extension ImportToken {
    static func make(tokensDataStore: TokensDataStore = FakeTokensDataStore(),
                     wallet: Wallet = .make(),
                     contractDataFetcher: ContractDataFetchable = FakeContractDataFetcher(),
                     server: RPCServer = .main) -> ImportToken {

        return .init(
            tokensDataStore: tokensDataStore,
            contractDataFetcher: contractDataFetcher,
            server: server,
            reachability: FakeReachabilityManager(false))
    }
}

final class FakeContractDataFetcher: ContractDataFetchable {
    var contractData: [AddressAndRPCServer: AlphaWalletFoundation.ContractData] = [:]
    private let server: RPCServer

    init(server: RPCServer = .main) {
        self.server = server
    }

    func fetchContractData(for contract: AlphaWallet.Address) -> AnyPublisher<ContractData, Never> {
        guard let contractData = contractData[.init(address: contract, server: server)] else { return .empty() }

        return Just(contract)
            .delay(for: .seconds(2), scheduler: RunLoop.main)
            .map { _ in contractData }
            .eraseToAnyPublisher()
    }
}

fileprivate extension Token {

    init(ercToken token: ErcToken, shouldUpdateBalance: Bool) {
        self.init(contract: token.contract, server: token.server, name: token.name, symbol: token.symbol, decimals: token.decimals, value: token.value, isCustom: true, type: token.type, balance: [])
    }
}
