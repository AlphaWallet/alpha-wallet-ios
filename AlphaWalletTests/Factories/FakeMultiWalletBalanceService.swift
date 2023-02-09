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
        walletAddressesStore.add(wallet: wallet)
    }

    return walletAddressesStore
}

final class FakeMultiWalletBalanceService: MultiWalletBalanceService {
    private var servers: [RPCServer] = []
    private let wallet: Wallet

    init(wallet: Wallet = .make(), servers: [RPCServer] = [.main]) {
        self.servers = servers
        self.wallet = wallet
        super.init(currencyService: .make())

        start(fetchers: [:])
    } 
}
