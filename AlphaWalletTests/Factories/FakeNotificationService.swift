//
//  FakeNotificationService.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 26.07.2022.
//

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation
import AlphaWalletNotifications

extension LocalNotificationService {
    static func fake() -> LocalNotificationService {
        let deliveryService = DefaultLocalNotificationDeliveryService(notificationCenter: .current())
        return LocalNotificationService(sources: [], deliveryService: deliveryService)
    }
}
