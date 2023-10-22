//
//  ReportUsersWalletAddresses.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Foundation
import Combine

public final class ReportUsersWalletAddresses: Service {
    private let keystore: Keystore
    private var cancelable = Set<AnyCancellable>()

    public init(keystore: Keystore) {
        self.keystore = keystore
    }

    public func perform() {
        //NOTE: make 2 sec delay to avoid load on launch
        keystore.walletsPublisher
            .delay(for: .seconds(2), scheduler: RunLoop.main)
            .sink { wallets in
                Task {
                    await crashlytics.track(wallets: Array(wallets))
                }
            }
            .store(in: &cancelable)
    }
}
