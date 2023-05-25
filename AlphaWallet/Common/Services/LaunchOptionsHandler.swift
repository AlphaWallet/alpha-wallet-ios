//
//  LaunchOptionsHandler.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.04.2023.
//

import UIKit
import AlphaWalletFoundation

public protocol LaunchOptionsHandler {
    func handle(launchOptions: [UIApplication.LaunchOptionsKey: Any]) async -> Bool
}

protocol ShortcutNavigatable: AnyObject {
    func launchUniversalScannerFromQuickAction()
}

class LaunchOptionsService {
    private let handlers: [LaunchOptionsHandler]

    init(handlers: [LaunchOptionsHandler]) {
        self.handlers = handlers
    }

    func handle(launchOptions: [UIApplication.LaunchOptionsKey: Any]) async -> Bool {
        var result = false
        for each in handlers {
            let isHandled = await each.handle(launchOptions: launchOptions)
            if isHandled {
                result = true
            }
        }

        return result
    }
}

import AlphaWalletNotifications

class PushNotificationLaunchOptionsHandler: LaunchOptionsHandler {
    private let pushNotificationsService: PushNotificationsService

    init(pushNotificationsService: PushNotificationsService) {
        self.pushNotificationsService = pushNotificationsService
    }

    func handle(launchOptions: [UIApplication.LaunchOptionsKey: Any]) async -> Bool {
        await pushNotificationsService.handle(launchOptions: launchOptions)
        return false
    }
}

class ShortcutHandler: LaunchOptionsHandler {

    weak var navigation: ShortcutNavigatable?

    func handle(launchOptions: [UIApplication.LaunchOptionsKey: Any]) async -> Bool {
        if let shortcutItem = launchOptions[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
            //Delay needed to work because app is launching..
            try? await Task.sleep(seconds: 0.3)
            return await self.handle(shortcutItem: shortcutItem)
        } else {
            return false
        }
    }

    func handle(shortcutItem: UIApplicationShortcutItem) async -> Bool {
        switch Shortcut(type: shortcutItem.type) {
        case .qrCodeScanner:
            await MainActor.run { navigation?.launchUniversalScannerFromQuickAction() }

            return true
        case .none:
            return false
        }
    }
}

extension ShortcutHandler {
    enum Shortcut {
        case qrCodeScanner

        init?(type: String) {
            switch type {
            case Constants.launchShortcutKey:
                self = .qrCodeScanner
            default:
                return nil
            }
        }
    }
}

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let duration = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: duration)
    }
}
