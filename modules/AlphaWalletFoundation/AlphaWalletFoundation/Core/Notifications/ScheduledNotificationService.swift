//
//  ScheduledNotificationService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.03.2022.
//

import Foundation
import UserNotifications

public protocol ScheduledNotificationService: AnyObject {
    func schedule(notification: LocalNotification)
}

