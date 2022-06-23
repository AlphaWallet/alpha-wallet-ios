// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import Combine
import PromiseKit

final class FakeSwapTokenService: TokenActionsService {
}

class TokensCoordinatorTests: XCTestCase {

    func testRootViewController() {
        var sessions = ServerDictionary<WalletSession>()
        sessions[.main] = WalletSession.make()
        let config: Config = .make()
        let tokenActionsService = FakeSwapTokenService()

        let coordinator = TokensCoordinator(
            navigationController: FakeNavigationController(),
            sessions: sessions,
            keystore: FakeKeystore(),
            config: config,
            assetDefinitionStore: AssetDefinitionStore(),
            eventsDataStore: FakeEventsDataStore(),
            promptBackupCoordinator: PromptBackupCoordinator(keystore: FakeKeystore(), wallet: .make(), config: config, analyticsCoordinator: FakeAnalyticsService()),
            analyticsCoordinator: FakeAnalyticsService(),
            openSea: OpenSea(analyticsCoordinator: FakeAnalyticsService(), queue: .global()),
            tokenActionsService: tokenActionsService,
            walletConnectCoordinator: .fake(),
            coinTickersFetcher: CoinTickersFetcher(provider: AlphaWalletProviderFactory.makeProvider(), config: config),
            activitiesService: FakeActivitiesService(),
            walletBalanceService: FakeMultiWalletBalanceService(),
            tokenCollection: MultipleChainsTokenCollection.fake(),
            importToken: FakeImportToken(),
            blockiesGenerator: .make(),
            domainResolutionService: FakeDomainResolutionService()
        )
        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is TokensViewController)
    }
}

class FakeImportToken: ImportToken {
    convenience init() {
        self.init(sessions: .init(.make()), wallet: .make(), tokensDataStore: FakeTokensDataStore(), assetDefinitionStore: .init())
    }
        //Adding a token may fail if we lose connectivity while fetching the contract details (e.g. name and balance). So we remove the contract from the hidden list (if it was there) so that the app has the chance to add it automatically upon auto detection at startup
    override func importToken(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool = false) -> Promise<Token> {
        return .init(error: PMKError.badInput)
    }

    override func importToken(token: ERCToken, shouldUpdateBalance: Bool = true) -> Token {
        return Token()
    }

    override func fetchContractData(for address: AlphaWallet.Address, server: RPCServer, completion: @escaping (ContractData) -> Void) {
        //no-op
    }

    override func fetchTokenOrContract(for contract: AlphaWallet.Address, server: RPCServer, onlyIfThereIsABalance: Bool = false) -> Promise<TokenOrContract> {
        return .init(error: PMKError.badInput)
    }
}
