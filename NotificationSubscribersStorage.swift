//
//  NotificationSubscribersStorage.swift
//  AlphaWalletNotifications
//
//  Created by Vladyslav Shepitko on 05.05.2023.
//

import Foundation
import AlphaWalletFoundation

public protocol NotificationSubscribersStorage: AnyObject {
    subscript(address: AlphaWallet.Address) -> Bool? { get set }
}

public class BaseNotificationSubscribersStorage: NotificationSubscribersStorage {
    private let defaults: UserDefaults

    public subscript(address: AlphaWallet.Address) -> Bool? {
        get { defaults.value(forKey: "push-notifications-\(address)") as? Bool }
        set { defaults.set(newValue, forKey: "push-notifications-\(address)") }
    }

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }
}
