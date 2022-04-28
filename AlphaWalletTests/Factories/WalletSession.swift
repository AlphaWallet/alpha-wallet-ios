// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import PromiseKit
import Combine
import RealmSwift
@testable import AlphaWallet

extension WalletSession {
    static func make(
        account: Wallet = .make(),
        server: RPCServer = .main,
        config: Config = .make(),
        tokenBalanceService: TokenBalanceService
    ) -> WalletSession {
        return WalletSession(
            account: account,
            server: server,
            config: config,
            tokenBalanceService: tokenBalanceService
        )
    }

    static func make(
        account: Wallet = .make(),
        server: RPCServer = .main,
        config: Config = .make()
    ) -> WalletSession {
        let tokenBalanceService = FakeSingleChainTokenBalanceService(wallet: account, server: server, etherToken: TokenObject(contract: AlphaWallet.Address.make(), server: server, value: "0", type: .nativeCryptocurrency))
        return WalletSession(
            account: account,
            server: server,
            config: config,
            tokenBalanceService: tokenBalanceService
        )
    }

    static func makeStormBirdSession(
        account: Wallet = .makeStormBird(),
        server: RPCServer,
        config: Config = .make(),
        tokenBalanceService: TokenBalanceService
    ) -> WalletSession {
        let tokenBalanceService = FakeSingleChainTokenBalanceService(wallet: account, server: server, etherToken: TokenObject(contract: AlphaWallet.Address.make(), server: server, value: "0", type: .nativeCryptocurrency))
        return WalletSession(
            account: account,
            server: server,
            config: config,
            tokenBalanceService: tokenBalanceService
        )
    }
}

private class FakeNftProvider: NFTProvider {
    func nonFungible(wallet: Wallet, server: RPCServer) -> Promise<NonFungiblesTokens> {
        return .value((openSea: [:], enjin: [:]))
    }
}

extension Realm {
    static func fake(forWallet wallet: Wallet) -> Realm {
        return try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "MyInMemoryRealm-\(wallet.address.eip55String)"))
    }
}

class FakeMultiWalletBalanceService: MultiWalletBalanceService {
    private var servers: [RPCServer] = []
    private let wallet: Wallet
    lazy var tokensDataStore = FakeTokensDataStore(account: wallet, servers: servers)

    init(wallet: Wallet = .make(), servers: [RPCServer] = [.main]) {
        self.servers = servers
        self.wallet = wallet

        let tickersFetcher = FakeCoinTickersFetcher()
        var walletAddressesStore = EtherKeystore.migratedWalletAddressesStore(userDefaults: .test)
        walletAddressesStore.addToListOfWatchEthereumAddresses(wallet.address)

        let keystore = FakeKeystore(wallets: [wallet], recentlyUsedWallet: wallet)
        super.init(keystore: keystore, config: .make(), assetDefinitionStore: .init(), coinTickersFetcher: tickersFetcher, walletAddressesStore: walletAddressesStore)
    }

    override func createWalletBalanceFetcher(wallet: Wallet) -> WalletBalanceFetcherType {
        let nftProvider = FakeNftProvider()
        let fetcher = WalletBalanceFetcher(wallet: wallet, servers: servers, tokensDataStore: tokensDataStore, transactionsStorage: FakeTransactionsStorage(), nftProvider: nftProvider, config: .make(), assetDefinitionStore: assetDefinitionStore, queue: .main, coinTickersFetcher: coinTickersFetcher)
        fetcher.delegate = self

        return fetcher
    }
}

class FakeSingleChainTokenBalanceService: SingleChainTokenBalanceService {
    private let balanceService: FakeMultiWalletBalanceService
    private let wallet: Wallet

    var tokensDataStore: TokensDataStore {
        balanceService.tokensDataStore
    }

    init(wallet: Wallet, server: RPCServer, etherToken: TokenObject) {
        self.wallet = wallet
        balanceService = FakeMultiWalletBalanceService(wallet: wallet, servers: [server])
        super.init(wallet: wallet, server: server, etherToken: etherToken, tokenBalanceProvider: balanceService)
    }

    func setBalanceTestsOnly(balance: Balance, forToken token: TokenObject) {
        balanceService.setBalanceTestsOnly(balance.value, forToken: token, wallet: wallet)
    }

    func addOrUpdateTokenTestsOnly(token: TokenObject) {
        balanceService.addOrUpdateTokenTestsOnly(token: token, wallet: wallet)
    }

    func deleteTokenTestsOnly(token: TokenObject) {
        balanceService.deleteTokenTestsOnly(token: token, wallet: wallet)
    }

    override func refresh(refreshBalancePolicy: PrivateBalanceFetcher.RefreshBalancePolicy) {
        //no-op
    }
}
