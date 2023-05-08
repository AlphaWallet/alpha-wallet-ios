//
//  FakeNotificationService.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 26.07.2022.
//

@testable import AlphaWallet
import AlphaWalletFoundation
import XCTest

extension NotificationService {
    static func fake() -> NotificationService {
        let notificationService = LocalNotificationService()
        return NotificationService(sources: [], walletBalanceService: FakeMultiWalletBalanceService(), notificationService: notificationService, pushNotificationsService: UNUserNotificationsService())
    }
}
