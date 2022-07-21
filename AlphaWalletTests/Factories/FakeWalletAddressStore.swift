//
//  FakeWalletAddressStore.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 20.07.2022.
//

import XCTest

@testable import AlphaWallet

func fakeWalletAddressStore(wallets: [FakeWallet] = [], recentlyUsedWallet: Wallet? = nil) -> WalletAddressesStore {
    var walletAddressesStore = EtherKeystore.migratedWalletAddressesStore(userDefaults: .test)
    for wallet in wallets {
        switch wallet.origin {
        case .privateKey:
            walletAddressesStore.addToListOfEthereumAddressesWithPrivateKeys(wallet.address)
        case .mnemonic:
            walletAddressesStore.addToListOfEthereumAddressesWithSeed(wallet.address)
        case .watch:
            walletAddressesStore.addToListOfWatchEthereumAddresses(wallet.address)
        }
    }
    walletAddressesStore.recentlyUsedWallet = recentlyUsedWallet

    return walletAddressesStore
}
