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

        let walletDependencyContainer = WalletComponentsFactory(
            analytics: FakeAnalyticsService(),
            nftProvider: FakeNftProvider(),
            assetDefinitionStore: .make(),
            coinTickersFetcher: CoinTickersFetcherImpl.make(),
            config: .make(),
            currencyService: .make(),
            networkService: FakeNetworkService(),
            rpcApiProvider: BaseRpcApiProvider.make(),
            sessionsParamsStorage: SessionsParamsFileStorage(privateNetworkRpcNodeParamsProvider: Config.make(), fileName: "fake-session-params"))

        super.init(
            walletAddressesStore: fakeWalletAddressesStore(wallets: [wallet]),
            dependencyContainer: walletDependencyContainer)
        start()
    } 
}
