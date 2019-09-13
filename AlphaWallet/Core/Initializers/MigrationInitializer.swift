// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import RealmSwift

class MigrationInitializer: Initializer {
    private let account: Wallet

    lazy var config: Realm.Configuration = {
        return RealmConfiguration.configuration(for: account)
    }()

    init(account: Wallet) {
        self.account = account
    }

    func perform() {
        config.schemaVersion = 5
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
        config.migrationBlock = { migration, oldSchemaVersion in
            if oldSchemaVersion < 4 {
                migration.enumerateObjects(ofType: TokenObject.className()) { oldObject, newObject in
                    guard let oldObject = oldObject else { return }
                    guard let newObject = newObject else { return }
                    //Fix bug introduced when OpenSea suddenly includes the DAI stablecoin token in their results with an existing versioned API endpoint, and we wrongly tagged it as ERC721, possibly crashing when we fetch the balance (casting a very large ERC20 balance with 18 decimals to an Int)
                    guard let contract = oldObject["contract"] as? String, contract == "0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359" else { return }
                    newObject["rawType"] = "ERC20"
                }
            }
        }
        config.migrationBlock = { migration, oldSchemaVersion in
            if oldSchemaVersion < 5 {
                migration.enumerateObjects(ofType: TokenObject.className()) { oldObject, newObject in
                    guard let oldObject = oldObject else { return }
                    guard let newObject = newObject else { return }
                    //Fix bug introduced when OpenSea suddenly includes the DAI stablecoin token in their results with an existing versioned API endpoint, and we wrongly tagged it as ERC721 with decimals=0. The earlier migration (version=4) only set the type back to ERC20, but the decimals remained as 0
                    guard let contract = oldObject["contract"] as? String, contract == "0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359" else { return }
                    newObject["decimals"] = 18
                }
            }
        }
    }
}
