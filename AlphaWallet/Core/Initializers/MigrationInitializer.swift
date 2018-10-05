// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import RealmSwift
import TrustKeystore

class MigrationInitializer: Initializer {
    private let account: Wallet
    private let chainID: Int

    lazy var config: Realm.Configuration = {
        return RealmConfiguration.configuration(for: account, chainID: chainID)
    }()

    init(
            account: Wallet, chainID: Int
    ) {
        self.account = account
        self.chainID = chainID
    }

    func perform() {
        config.schemaVersion = 49
        config.migrationBlock = { migration, oldSchemaVersion in
            switch oldSchemaVersion {
            case 0...32:
                migration.enumerateObjects(ofType: TokenObject.className()) { oldObject, newObject in

                    guard let oldObject = oldObject else { return }
                    guard let newObject = newObject else { return }
                    guard let value = oldObject["contract"] as? String else { return }
                    guard let address = Address(string: value) else { return }

                    newObject["contract"] = address.description
                }
            default: break
            }
            if oldSchemaVersion < 44 {
                migration.enumerateObjects(ofType: TokenObject.className()) { oldObject, newObject in
                    guard let oldObject = oldObject else { return }
                    guard let newObject = newObject else { return }
                    if let isStormbird = oldObject["isStormBird"] as? Bool {
                        newObject["rawType"] = isStormbird ? TokenType.erc875.rawValue : TokenType.erc20.rawValue
                    }
                }
            }
            if oldSchemaVersion < 48 {
                migration.enumerateObjects(ofType: TokenObject.className()) { oldObject, newObject in
                    guard let oldObject = oldObject else { return }
                    guard let newObject = newObject else { return }
                    if let contract = oldObject["contract"] as? String, contract == Constants.nullAddress {
                        newObject["rawType"] = TokenType.ether.rawValue
                    }
                }
            }
            if oldSchemaVersion < 49 {
                //In schemaVersion 49, we clear the token's `name` because we want it to only contain the name returned by the RPC name call and not the localized text
                migration.enumerateObjects(ofType: TokenObject.className()) { oldObject, newObject in
                    guard let oldObject = oldObject else { return }
                    guard let newObject = newObject else { return }
                    if let contract = oldObject["contract"] as? String {
                        let tokenTypeName = XMLHandler(contract: contract).getName()
                        if tokenTypeName != "N/A" {
                            newObject["name"] = ""
                        }
                    }
                }
            }
        }
    }
}
