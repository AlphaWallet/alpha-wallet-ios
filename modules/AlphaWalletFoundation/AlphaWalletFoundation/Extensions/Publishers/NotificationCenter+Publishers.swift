//
//  NotificationCenter+Publishers.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.04.2022.
//

import Foundation
import Combine
import UIKit

extension NotificationCenter {

    enum Notification {
        case willEnterForeground
        case didEnterBackground
    }

    var willEnterForeground: AnyPublisher<NotificationCenter.Notification, Never> {
        publisher(for: UIApplication.willEnterForegroundNotification)
            .map { _ in return .willEnterForeground }
            .eraseToAnyPublisher()
    }

    var didEnterBackground: AnyPublisher<NotificationCenter.Notification, Never> {
        publisher(for: UIApplication.didEnterBackgroundNotification)
            .map { _ in return .didEnterBackground }
            .eraseToAnyPublisher()
    }

    var applicationState: AnyPublisher<NotificationCenter.Notification, Never> {
        Publishers.Merge(willEnterForeground, didEnterBackground)
            .eraseToAnyPublisher()
    }
}
