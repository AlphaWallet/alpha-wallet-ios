//
//  PrivateTokensDataStoreType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.06.2021.
//

import Foundation
import BigInt
import PromiseKit
import Result
import RealmSwift
import SwiftyJSON

protocol PrivateTokensDatastoreType {
    var enabledObjects: Results<TokenObject> { get }
    var tokenObjects: [Activity.AssignedToken] { get }

    func addOrUpdateErc271(contract: AlphaWallet.Address, openSeaNonFungibles: [OpenSeaNonFungible], tokens: [Activity.AssignedToken], completion: @escaping () -> Void)
    func addCustom(token: ERCToken, completion: @escaping () -> Void)
    func update(primaryKey: String, action: PrivateTokensDatastore.TokenUpdateAction, completion: @escaping (Bool?) -> Void)
    func tokenObject(contract: AlphaWallet.Address) -> TokenObject?
}

class PrivateTokensDatastore: PrivateTokensDatastoreType {
    private let realm: Realm
    private let server: RPCServer

    private var chainId: Int {
        return server.chainID
    }

    private var objects: Results<TokenObject> {
        realm
            .threadSafe
            .objects(TokenObject.self)
            .filter("chainId = \(self.chainId)")
            .filter("contract != ''")
    }

    var enabledObjects: Results<TokenObject> {
        objects.filter("isDisabled = false")
    }

    var tokenObjects: [Activity.AssignedToken] {
        let tokenObjects = enabledObjects.map { Activity.AssignedToken(tokenObject: $0) }
        return Array(tokenObjects)
    }

    private let backgroundQueue: DispatchQueue

    init(realm: Realm, server: RPCServer, queue: DispatchQueue) {
        self.server = server
        self.backgroundQueue = queue
        self.realm = realm
    }

    func tokenObject(contract: AlphaWallet.Address) -> TokenObject? {
        return enabledObjects.filter("contract = '\(contract.eip55String)'").first
    }

    enum TokenUpdateAction {
        case value(BigInt)
        case nonFungibleBalance([String])
        case name(String)
        case type(TokenType)
    }

    func addOrUpdateErc271(contract: AlphaWallet.Address, openSeaNonFungibles: [OpenSeaNonFungible], tokens: [Activity.AssignedToken], completion: @escaping () -> Void) {
        var listOfJson = [String]()
        var anyNonFungible: OpenSeaNonFungible?
        for each in openSeaNonFungibles {
            if let encodedJson = try? JSONEncoder().encode(each), let jsonString = String(data: encodedJson, encoding: .utf8) {
                anyNonFungible = each
                listOfJson.append(jsonString)
            } else {
                //no op
            }
        }

        if let tokenObject = tokens.first(where: { $0.contractAddress.sameContract(as: contract) }) {
            let group = DispatchGroup()

            switch tokenObject.type {
            case .nativeCryptocurrency, .erc721, .erc875, .erc721ForTickets:
                break
            case .erc20:
                group.enter()
                update(primaryKey: tokenObject.primaryKey, action: .type(.erc721)) { _ in
                    group.leave()
                }
            }

            group.enter()
            update(primaryKey: tokenObject.primaryKey, action: .nonFungibleBalance(listOfJson)) { _ in
                group.leave()
            }

            if let anyNonFungible = anyNonFungible {
                group.enter()
                update(primaryKey: tokenObject.primaryKey, action: .name(anyNonFungible.contractName)) { _ in
                    group.leave()
                }
            }

            group.notify(queue: self.backgroundQueue) {
                completion()
            }
        } else {
            let token = ERCToken(
                    contract: contract,
                    server: server,
                    name: openSeaNonFungibles[0].contractName,
                    symbol: openSeaNonFungibles[0].symbol,
                    decimals: 0,
                    type: .erc721,
                    balance: listOfJson
            )

            addCustom(token: token, completion: completion)
        }
    }

    func addCustom(token: ERCToken, completion: @escaping () -> Void) {
        backgroundQueue.async {
            let backgroundRealm = self.realm.threadSafe
            let newToken = TokenObject(
                    contract: token.contract,
                    server: token.server,
                    name: token.name,
                    symbol: token.symbol,
                    decimals: token.decimals,
                    value: "0",
                    isCustom: true,
                    type: token.type
            )
            token.balance.forEach { balance in
                newToken.balance.append(TokenBalance(balance: balance))
            }

            if let object = backgroundRealm.object(ofType: TokenObject.self, forPrimaryKey: newToken.primaryKey) {
                newToken.sortIndex = object.sortIndex
                newToken.shouldDisplay = object.shouldDisplay
            }

            do {
                backgroundRealm.beginWrite()

                backgroundRealm.add(newToken, update: .all)

                try backgroundRealm.commitWrite()

            } catch {
                //no-op
            }
            completion()
        }
    }

    func update(primaryKey: String, action: TokenUpdateAction, completion: @escaping (Bool?) -> Void) {
        backgroundQueue.async {
            let backgroundRealm = self.realm.threadSafe
            guard let tokenObject = backgroundRealm.object(ofType: TokenObject.self, forPrimaryKey: primaryKey) else {
                completion(nil)
                return
            }

            var result: Bool = false
            backgroundRealm.beginWrite()

            switch action {
            case .value(let value):
                let valueHasChanged = tokenObject.value != value.description
                tokenObject.value = value.description

                result = valueHasChanged
            case .nonFungibleBalance(let balance):
                var newBalance = [TokenBalance]()
                if !balance.isEmpty {
                    for i in 0...balance.count - 1 {
                        if let oldBalance = tokenObject.balance.first(where: { $0.balance == balance[i] }) {
                            newBalance.append(TokenBalance(balance: balance[i], json: oldBalance.json))
                        } else {
                            newBalance.append(TokenBalance(balance: balance[i]))
                        }
                    }
                }

                backgroundRealm.delete(tokenObject.balance)
                tokenObject.balance.append(objectsIn: newBalance)

                //NOTE: for now we mark balance as hasn't changed for nonFungibleBalance, How to check that balance has update?
                result = true
            case .name(let name):
                tokenObject.name = name

                result = true
            case .type(let type):
                tokenObject.rawType = type.rawValue

                result = true
            }

            do {
                try backgroundRealm.commitWrite()
                completion(result)
            } catch {
                completion(nil)
            }
        }
    }
}

