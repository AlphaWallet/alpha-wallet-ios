//
//  LaunchOptionsHandler.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.04.2023.
//

import UIKit
import AlphaWalletFoundation

public protocol LaunchOptionsHandler {
    func handle(launchOptions: [UIApplication.LaunchOptionsKey: Any]) -> Bool
}

protocol ShortcutLaunchOptionsHandlerDelegate: AnyObject {
    func launchUniversalScannerFromQuickAction()
}

class LaunchOptionsService {
    private let handlers: [LaunchOptionsHandler]

    init(handlers: [LaunchOptionsHandler]) {
        self.handlers = handlers
    }

    func handle(launchOptions: [UIApplication.LaunchOptionsKey: Any]) {
        for each in handlers where each.handle(launchOptions: launchOptions) {
            break
        }
    }
}

class ShortcutHandler: LaunchOptionsHandler {

    weak var delegate: ShortcutLaunchOptionsHandlerDelegate?

    func handle(launchOptions: [UIApplication.LaunchOptionsKey: Any]) -> Bool {
        if let shortcutItem = launchOptions[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem, canHandle(shortcutItem: shortcutItem) {
            //Delay needed to work because app is launching..
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.handle(shortcutItem: shortcutItem)
            }
            return true
        } else {
            return false
        }
    }

    func canHandle(shortcutItem: UIApplicationShortcutItem) -> Bool {
        Shortcut(type: shortcutItem.type) != nil
    }

    func handle(shortcutItem: UIApplicationShortcutItem) {
        switch Shortcut(type: shortcutItem.type) {
        case .qrCodeScanner:
            delegate?.launchUniversalScannerFromQuickAction()
        case .none:
            break
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
