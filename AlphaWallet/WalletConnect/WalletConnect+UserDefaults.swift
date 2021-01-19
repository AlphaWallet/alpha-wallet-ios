//
//  WalletConnect+UserDefaults.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.10.2020.
//

import Foundation

extension UserDefaults {
    private static let walletConnectSessionsKey = "WalletConnectSessionsKey"
    private static let urlToServerKey = "urlToServerKey"

    var walletConnectSessions: [WalletConnectSession] {
        get {
            guard let data = object(forKey: UserDefaults.walletConnectSessionsKey) as? Data, let sessions = try? JSONDecoder().decode([WalletConnectSession].self, from: data) else { return [] }
            if let session = sessions.first, let walletAddress = session.walletInfo?.accounts[0] {
                //Make sure to clear WalletConnect sessions if we change wallet
                if EtherKeystore.currentWallet.address.sameContract(as: walletAddress) {
                    //no-op
                } else {
                    self.walletConnectSessions = []
                    //here we need to return an empty array [] if we removed all sessions
                    return []
                }
            }
            return sessions
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            set(data, forKey: UserDefaults.walletConnectSessionsKey)
        }
    }

    var urlToServer: [WalletConnectURL: RPCServer] {
        get {
            guard let data = object(forKey: UserDefaults.urlToServerKey) as? Data, let values = try? JSONDecoder().decode([WalletConnectURL: RPCServer].self, from: data) else {
                return [:]
            }
            
            return values
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            set(data, forKey: UserDefaults.urlToServerKey)
        }
    }
}
