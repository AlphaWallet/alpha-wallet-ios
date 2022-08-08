//
//  FakeMultiWalletBalanceService.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

@testable import AlphaWallet

class FakeMultiWalletBalanceService: MultiWalletBalanceService {
    private var servers: [RPCServer] = []
    private let wallet: Wallet
    lazy var tokensDataStore = FakeTokensDataStore(account: wallet, servers: servers)

    init(wallet: Wallet = .make(), servers: [RPCServer] = [.main]) {
        self.servers = servers
        self.wallet = wallet

        let walletAddressesStore = fakeWalletAddressStore(wallets: [.init(wallet: wallet)])
        let keystore = FakeEtherKeystore(walletAddressesStore: walletAddressesStore)
        super.init(store: FakeRealmLocalStore(), keystore: keystore, config: .make(), assetDefinitionStore: .init(), analytics: FakeAnalyticsService(), coinTickersFetcher: CoinGeckoTickersFetcher.make(), walletAddressesStore: walletAddressesStore)
    }

    override func createWalletBalanceFetcher(wallet: Wallet) -> WalletBalanceFetcherType {
        let nftProvider = FakeNftProvider()
        let analytics = FakeAnalyticsService()
        let fetcher = WalletBalanceFetcher(wallet: wallet, servers: servers, tokensDataStore: tokensDataStore, transactionsStorage: FakeTransactionsStorage(), nftProvider: nftProvider, config: .make(), assetDefinitionStore: assetDefinitionStore, analytics: analytics, queue: .main, coinTickersFetcher: coinTickersFetcher)
        fetcher.delegate = self

        return fetcher
    }
}
