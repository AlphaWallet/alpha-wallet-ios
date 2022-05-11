//
//  ReportUsersWalletAddresses.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Foundation
import Combine

final class ReportUsersWalletAddresses: Initializer {
    private let walletAddressesStore: WalletAddressesStore
    private var cancelable = Set<AnyCancellable>()
    
    init(walletAddressesStore: WalletAddressesStore) {
        self.walletAddressesStore = walletAddressesStore
    }

    func perform() {
        walletAddressesStore.walletsPublisher.sink { wallets in
            crashlytics.track(wallets: Array(wallets))
        }.store(in: &cancelable)
    }
}
