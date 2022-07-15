//
//  FakeNotificationService.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 26.07.2022.
//

import XCTest
@testable import AlphaWallet

final class FakeNotificationService: NotificationService {
    init() {
        super.init(sources: [], walletBalanceService: FakeMultiWalletBalanceService())
    }
}
