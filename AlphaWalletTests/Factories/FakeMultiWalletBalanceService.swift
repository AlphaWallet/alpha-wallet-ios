//
//  FakeMultiWalletBalanceService.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//
import AlphaWalletFoundation
@testable import AlphaWallet

func fakeWalletAddressesStore(wallets: [Wallet] = [.make()]) -> WalletAddressesStore {
    var walletAddressesStore = EtherKeystore.migratedWalletAddressesStore(userDefaults: .test)
    for wallet in wallets {
        switch wallet.type {
        case .real:
            walletAddressesStore.addToListOfEthereumAddressesWithSeed(wallet.address)
        case .watch:
            walletAddressesStore.addToListOfWatchEthereumAddresses(wallet.address)
        }
    }

    return walletAddressesStore
}

final class FakeMultiWalletBalanceService: MultiWalletBalanceService {
    private var servers: [RPCServer] = []
    private let wallet: Wallet

    init(wallet: Wallet = .make(), servers: [RPCServer] = [.main]) {
        self.servers = servers
        self.wallet = wallet

        let tickersFetcher = CoinGeckoTickersFetcher.make()
        let walletAddressesStore = fakeWalletAddressesStore(wallets: [wallet])

        let fas = FakeAnalyticsService()
        let fnftp = FakeNftProvider()
        let walletDependencyContainer = WalletComponentsFactory(analytics: fas, nftProvider: fnftp, assetDefinitionStore: .init(), coinTickersFetcher: tickersFetcher, config: .make())
        super.init(walletAddressesStore: walletAddressesStore, dependencyContainer: walletDependencyContainer)
        start()
    } 
}
