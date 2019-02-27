// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import RealmSwift
import TrustKeystore

struct RealmConfiguration {
    static func configuration(for account: Wallet, server: RPCServer) -> Realm.Configuration {
        var config = Realm.Configuration()
        config.fileURL = config.fileURL!.deletingLastPathComponent().appendingPathComponent("\(account.address.description.lowercased())-\(server.chainID).realm")
        return config
    }

    static func configuration(for account: Wallet) -> Realm.Configuration {
        var config = Realm.Configuration()
        config.fileURL = config.fileURL!.deletingLastPathComponent().appendingPathComponent("\(account.address.description.lowercased()).realm")
        return config
    }
}
