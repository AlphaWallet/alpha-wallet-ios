//
//  ReportUsersWalletAddresses.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Foundation
import Combine

public final class ReportUsersWalletAddresses: Initializer {
    private let walletAddressesStore: WalletAddressesStore
    private var cancelable = Set<AnyCancellable>()
    
    public init(walletAddressesStore: WalletAddressesStore) {
        self.walletAddressesStore = walletAddressesStore
    }

    public func perform() {
        //NOTE: make 2 sec delay to avoid load on launch
        walletAddressesStore.walletsPublisher.delay(for: .seconds(2), scheduler: RunLoop.main).sink { wallets in
            crashlytics?.track(wallets: Array(wallets))
        }.store(in: &cancelable)
    }
}
