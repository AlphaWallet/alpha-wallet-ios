// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import RealmSwift

class EventActivity: Object {
    static func generatePrimaryKey(fromContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String, blockNumber: Int, transactionId: String, logIndex: Int, filter: String) -> String {
        "\(contract.eip55String)-\(tokenContract.eip55String)-\(server.chainID)-\(eventName)-\(blockNumber)-\(transactionId)-\(logIndex)-\(filter)"
    }

    @objc dynamic var primaryKey: String = ""
    @objc dynamic var contract: String = Constants.nullAddress.eip55String
    @objc dynamic var tokenContract: String = Constants.nullAddress.eip55String
    @objc dynamic var chainId: Int = 0
    @objc dynamic var date = Date()
    @objc dynamic var eventName: String = ""
    @objc dynamic var blockNumber: Int = 0
    @objc dynamic var transactionId: String = ""
    @objc dynamic var transactionIndex: Int = 0
    @objc dynamic var logIndex: Int = 0
    @objc dynamic var filter: String = ""
    @objc dynamic var json: String = "{}" {
        didSet {
            _data = EventActivity.convertJsonToDictionary(json)
        }
    }

    //Needed because Realm objects' properties (`json`) don't fire didSet after the object has been written to the database
    var _data: [String: AssetInternalValue]?
    var data: [String: AssetInternalValue] {
        if let _data = _data {
            return _data
        } else {
            let value = EventActivity.convertJsonToDictionary(json)
            _data = value
            return value
        }
    }

    var tokenContractAddress: AlphaWallet.Address {
        AlphaWallet.Address(uncheckedAgainstNullAddress: tokenContract)!
    }

    var server: RPCServer {
        .init(chainID: chainId)
    }

    convenience init(contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, date: Date, eventName: String, blockNumber: Int, transactionId: String, transactionIndex: Int, logIndex: Int, filter: String, json: String) {
        self.init()
        self.primaryKey = EventActivity.generatePrimaryKey(fromContract: contract, tokenContract: tokenContract, server: server, eventName: eventName, blockNumber: blockNumber, transactionId: transactionId, logIndex: logIndex, filter: filter)
        self.contract = contract.eip55String
        self.tokenContract = tokenContract.eip55String
        self.chainId = server.chainID
        self.date = date
        self.eventName = eventName
        self.blockNumber = blockNumber
        self.transactionId = transactionId
        self.transactionIndex = transactionIndex
        self.logIndex = logIndex
        self.filter = filter
        self.json = json
        self._data = EventActivity.convertJsonToDictionary(json)
    }

    convenience init(value: EventActivityInstance) {
        self.init()
        self.primaryKey = value.primaryKey
        self.contract = value.contract.eip55String
        self.tokenContract = value.tokenContract.eip55String
        self.chainId = value.server.chainID
        self.date = value.date
        self.eventName = value.eventName
        self.blockNumber = value.blockNumber
        self.transactionId = value.transactionId
        self.transactionIndex = value.transactionIndex
        self.logIndex = value.logIndex
        self.filter = value.filter
        self.json = value.json
        self._data = value.data
    }

    override static func primaryKey() -> String? {
        return "primaryKey"
    }

    override static func ignoredProperties() -> [String] {
        return ["_data", "data"]
    }

    private static func convertJsonToDictionary(_ json: String) -> [String: AssetInternalValue] {
        let dict = json.data(using: .utf8).flatMap({ (try? JSONSerialization.jsonObject(with: $0, options: [])) as? [String: Any] }) ?? .init()
        return Dictionary(uniqueKeysWithValues: dict.compactMap { key, value -> (String, AssetInternalValue)? in
            switch value {
            case let string as String:
                return (key, .string(string))
            case let number as NSNumber:
                return (key, .string(String(describing: number)))
            default:
                return nil
            }
        })
    }
}

struct EventActivityInstance {
    static func generatePrimaryKey(fromContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String, blockNumber: Int, transactionId: String, logIndex: Int, filter: String) -> String {
        "\(contract.eip55String)-\(tokenContract.eip55String)-\(server.chainID)-\(eventName)-\(blockNumber)-\(transactionId)-\(logIndex)-\(filter)"
    }

    var primaryKey: String = ""
    var contract: AlphaWallet.Address
    var tokenContract: AlphaWallet.Address
    var server: RPCServer
    var date = Date()
    var eventName: String = ""
    var blockNumber: Int = 0
    var transactionId: String = ""
    var transactionIndex: Int = 0
    var logIndex: Int = 0
    var filter: String = ""
    var json: String = "{}"

    //Needed because Realm objects' properties (`json`) don't fire didSet after the object has been written to the database
    var data: [String: AssetInternalValue]

    init(event: EventActivity) {
        self.primaryKey = event.primaryKey

        self.contract = AlphaWallet.Address(uncheckedAgainstNullAddress: event.contract)!
        self.tokenContract = AlphaWallet.Address(uncheckedAgainstNullAddress: event.tokenContract)!
        self.server = RPCServer(chainID: event.chainId)
        self.date = event.date
        self.eventName = event.eventName
        self.blockNumber = event.blockNumber
        self.transactionId = event.transactionId
        self.transactionIndex = event.transactionIndex
        self.logIndex = event.logIndex
        self.filter = event.filter
        self.json = event.json
        self.data = event.data
    }

    init(contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, date: Date, eventName: String, blockNumber: Int, transactionId: String, transactionIndex: Int, logIndex: Int, filter: String, json: String) {
        self.primaryKey = EventActivity.generatePrimaryKey(fromContract: contract, tokenContract: tokenContract, server: server, eventName: eventName, blockNumber: blockNumber, transactionId: transactionId, logIndex: logIndex, filter: filter)
        self.contract = contract
        self.tokenContract = tokenContract
        self.server = server
        self.date = date
        self.eventName = eventName
        self.blockNumber = blockNumber
        self.transactionId = transactionId
        self.transactionIndex = transactionIndex
        self.logIndex = logIndex
        self.filter = filter
        self.json = json
        self.data = EventActivityInstance.convertJsonToDictionary(json)
    }

    private static func convertJsonToDictionary(_ json: String) -> [String: AssetInternalValue] {
        let dict = json.data(using: .utf8).flatMap({ (try? JSONSerialization.jsonObject(with: $0, options: [])) as? [String: Any] }) ?? .init()
        return Dictionary(uniqueKeysWithValues: dict.compactMap { key, value -> (String, AssetInternalValue)? in
            switch value {
            case let string as String:
                return (key, .string(string))
            case let number as NSNumber:
                return (key, .string(String(describing: number)))
            default:
                return nil
            }
        })
    }
}
