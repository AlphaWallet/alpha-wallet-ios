// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import Combine
import PromiseKit
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
        var sessions = ServerDictionary<WalletSession>()
        sessions[.main] = WalletSession.make()
        let config: Config = .make()
        let tokenActionsService = FakeSwapTokenService()
        let wallet: Wallet = .make()
        let dep = WalletDataProcessingPipeline.make(wallet: .make(), server: .main)
        let walletAddressesStore = fakeWalletAddressStore(wallets: [wallet], recentlyUsedWallet: .make())
        let walletBalanceService = FakeMultiWalletBalanceService(wallet: wallet, servers: [.main])
        
        let coordinator = TokensCoordinator(
            navigationController: FakeNavigationController(),
            sessions: sessions,
            keystore: FakeEtherKeystore(),
            config: config,
            assetDefinitionStore: .make(),
            promptBackupCoordinator: .make(wallet: wallet),
            analytics: FakeAnalyticsService(),
            nftProvider: FakeNftProvider(),
            tokenActionsService: tokenActionsService,
            walletConnectCoordinator: .fake(),
            coinTickersFetcher: CoinTickersFetcherImpl.make(),
            activitiesService: FakeActivitiesService(),
            walletBalanceService: FakeMultiWalletBalanceService(),
            tokenCollection: dep.pipeline,
            importToken: dep.importToken,
            blockiesGenerator: .make(),
            domainResolutionService: FakeDomainResolutionService(),
            tokensFilter: .make(),
            currencyService: .make())

        coordinator.start()

        XCTAssertTrue(coordinator.navigationController.viewControllers[0] is TokensViewController)
    }
}

extension ImportToken {
    static func make(tokensDataStore: TokensDataStore = FakeTokensDataStore(), wallet: Wallet = .make(), contractDataFetcher: ContractDataFetchable = FakeContractDataFetcher()) -> ImportToken {
        return .init(tokensDataStore: tokensDataStore, contractDataFetcher: contractDataFetcher)
    }
}

final class FakeContractDataFetcher: ContractDataFetchable {
    var contractData: [AddressAndRPCServer: AlphaWalletFoundation.ContractData] = [:]

    func fetchContractData(for contract: AlphaWallet.Address, server: RPCServer, completion: @escaping (ContractData) -> Void) {
        guard let contractData = contractData[.init(address: contract, server: server)] else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            completion(contractData)
        }
    }
}

fileprivate extension Token {

    init(ercToken token: ErcToken, shouldUpdateBalance: Bool) {
        self.init(contract: token.contract, server: token.server, name: token.name, symbol: token.symbol, decimals: token.decimals, value: token.value, isCustom: true, type: token.type, balance: [])
    }
}
