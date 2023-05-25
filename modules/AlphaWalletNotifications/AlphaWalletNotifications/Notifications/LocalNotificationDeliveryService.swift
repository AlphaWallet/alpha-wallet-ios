//
//  LocalNotificationDeliveryService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.03.2022.
//

import Foundation
import UserNotifications

public protocol LocalNotificationDeliveryService: AnyObject {
    func schedule(notification: LocalNotification) async throws
}

