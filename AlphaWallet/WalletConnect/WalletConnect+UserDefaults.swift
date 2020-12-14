//
//  WalletConnect+UserDefaults.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.10.2020.
//

import Foundation

extension UserDefaults {
    private static let lastSessionKey = "LastSessionKey"

    var lastSession: WalletConnectSession? {
        get {
            guard let data = object(forKey: UserDefaults.lastSessionKey) as? Data, let session = try? JSONDecoder().decode(WalletConnectSession.self, from: data) else {
                return nil
            }

            return session
        }
        set {
            if let value = newValue {
                if let data = try? JSONEncoder().encode(value) {
                    set(data, forKey: UserDefaults.lastSessionKey)
                }

            } else {
                removeObject(forKey: UserDefaults.lastSessionKey)
            }
        }
    }
}
