// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import RealmSwift
import TrustKeystore

class MigrationInitializer: Initializer {
    private let account: Wallet

    lazy var config: Realm.Configuration = {
        return RealmConfiguration.configuration(for: account)
    }()

    init(account: Wallet) {
        self.account = account
    }

    func perform() {
        config.schemaVersion = 3
        config.migrationBlock = { migration, oldSchemaVersion in
            if oldSchemaVersion < 2 {
                //Fix bug created during multi-chain implementation. Where TokenObject instances are created from transfer Transaction instances, with the primaryKey as a empty string; so instead of updating an existing TokenObject, a duplicate TokenObject instead was created but with primaryKey empty
                migration.enumerateObjects(ofType: TokenObject.className()) { oldObject, newObject in
                    guard let _ = oldObject else { return }
                    guard let newObject = newObject else { return }
                    if let primaryKey = newObject["primaryKey"] as? String, primaryKey.isEmpty {
                        migration.delete(newObject)
                        return
                    }
                }
            }
        }
        config.migrationBlock = { migration, oldSchemaVersion in
            if oldSchemaVersion < 3 {
                migration.enumerateObjects(ofType: Transaction.className()) { oldObject, newObject in
                    guard let _ = oldObject else { return }
                    guard let newObject = newObject else { return }
                    newObject["isERC20Interaction"] = false 
                }
            }
        }
    }
}
