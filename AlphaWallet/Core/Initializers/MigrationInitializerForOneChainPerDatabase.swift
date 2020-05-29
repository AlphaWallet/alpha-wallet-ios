// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import RealmSwift

///This class shouldn't be modified since we have migrated to a Realm database that contains data from all chains
class MigrationInitializerForOneChainPerDatabase: Initializer {
    private let account: Wallet
    private let server: RPCServer
    private let assetDefinitionStore: AssetDefinitionStore

    lazy var config: Realm.Configuration = {
        return RealmConfiguration.configuration(for: account, server: server)
    }()

    init(account: Wallet, server: RPCServer, assetDefinitionStore: AssetDefinitionStore) {
        self.account = account
        self.server = server
        self.assetDefinitionStore = assetDefinitionStore
    }

// swiftlint:disable function_body_length
    func perform() {
        config.schemaVersion = 53
        config.migrationBlock = { migration, oldSchemaVersion in
            if oldSchemaVersion < 33 {
                migration.enumerateObjects(ofType: TokenObject.className()) { oldObject, newObject in
                    guard let oldObject = oldObject else { return }
                    guard let newObject = newObject else { return }
                    guard let value = oldObject["contract"] as? String else { return }
                    guard let address = AlphaWallet.Address(string: value) else { return }

                    newObject["contract"] = address.eip55String
                }
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
                    if let contract = oldObject["contract"] as? String, Constants.nativeCryptoAddressInDatabase.sameContract(as: contract) {
                        newObject["rawType"] = TokenType.nativeCryptocurrency.rawValue
                    }
                }
            }
            if oldSchemaVersion < 49 {
                //In schemaVersion 49, we clear the token's `name` because we want it to only contain the name returned by the RPC name call and not the localized text
                migration.enumerateObjects(ofType: TokenObject.className()) { oldObject, newObject in
                    guard let oldObject = oldObject else { return }
                    guard let newObject = newObject else { return }
                    if let contract = (oldObject["contract"] as? String).flatMap({ AlphaWallet.Address(uncheckedAgainstNullAddress: $0) }) {
                        let tokenTypeName = XMLHandler(contract: contract, assetDefinitionStore: self.assetDefinitionStore).getLabel(fallback: "")
                        if !tokenTypeName.isEmpty {
                            newObject["name"] = ""
                        }
                    }
                }
            }
            if oldSchemaVersion < 51 {
                var bookmarkOrder = 0
                migration.enumerateObjects(ofType: Bookmark.className()) { _, newObject in
                    guard let newObject = newObject else { return }
                    newObject["order"] = bookmarkOrder
                    bookmarkOrder += 1
                }
            }
            if oldSchemaVersion < 52 {
                migration.deleteData(forType: Transaction.className())
            }
            if oldSchemaVersion < 53 {
                let chainId = self.server.chainID
                migration.enumerateObjects(ofType: TokenObject.className()) { _, newObject in
                    guard let newObject = newObject else { return }
                    guard let contract = newObject["contract"] as? String else {
                        migration.delete(newObject)
                        return
                    }
                    newObject["chainId"] = chainId
                    newObject["primaryKey"] = "\(contract)-\(chainId)"
                }
                migration.enumerateObjects(ofType: Transaction.className()) { _, newObject in
                    guard let newObject = newObject else { return }
                    guard let id = newObject["id"] as? String else {
                        migration.delete(newObject)
                        return
                    }
                    newObject["chainId"] = chainId
                    newObject["primaryKey"] = "\(id)-\(chainId)"
                }
                //DelegateContract, HiddenContract, DeletedContract needs to check for duplicate because they didn't have a primary key
                var existingDelegateContracts = [String]()
                migration.enumerateObjects(ofType: DelegateContract.className()) { _, newObject in
                    guard let newObject = newObject else { return }
                    guard let contract = newObject["contract"] as? String else {
                        migration.delete(newObject)
                        return
                    }
                    if existingDelegateContracts.contains(contract) {
                        migration.delete(newObject)
                    } else {
                        newObject["chainId"] = chainId
                        newObject["primaryKey"] = "\(contract)-\(chainId)"
                        existingDelegateContracts.append(contract)
                    }
                }
                var existingHiddenContracts = [String]()
                migration.enumerateObjects(ofType: HiddenContract.className()) { _, newObject in
                    guard let newObject = newObject else { return }
                    guard let contract = newObject["contract"] as? String else {
                        migration.delete(newObject)
                        return
                    }
                    if existingHiddenContracts.contains(contract) {
                        migration.delete(newObject)
                    } else {
                        newObject["chainId"] = chainId
                        newObject["primaryKey"] = "\(contract)-\(chainId)"
                        existingHiddenContracts.append(contract)
                    }
                }
                var existingDeletedContracts = [String]()
                migration.enumerateObjects(ofType: DeletedContract.className()) { _, newObject in
                    guard let newObject = newObject else { return }
                    guard let contract = newObject["contract"] as? String else {
                        migration.delete(newObject)
                        return
                    }
                    if existingDeletedContracts.contains(contract) {
                        migration.delete(newObject)
                    } else {
                        newObject["chainId"] = chainId
                        newObject["primaryKey"] = "\(contract)-\(chainId)"
                        existingDeletedContracts.append(contract)
                    }
                }
            }
        }
    }
// swiftlint:enable function_body_length
}
