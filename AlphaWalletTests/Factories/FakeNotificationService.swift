//
//  FakeNotificationService.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 26.07.2022.
//

@testable import AlphaWallet
import AlphaWalletFoundation
import AlphaWalletNotifications
import XCTest

extension LocalNotificationService {
    static func fake() -> LocalNotificationService {
        let deliveryService = DefaultLocalNotificationDeliveryService(notificationCenter: .current())
        return LocalNotificationService(sources: [], deliveryService: deliveryService)
    }
}
