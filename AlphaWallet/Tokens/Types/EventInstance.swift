// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import RealmSwift

class EventInstance: Object {
    static func generatePrimaryKey(fromContract contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String, blockNumber: Int, logIndex: Int, filter: String) -> String {
        "\(contract.eip55String)-\(tokenContract.eip55String)-\(server.chainID)-\(eventName)-\(blockNumber)-\(logIndex)-\(filter)"
    }

    @objc dynamic var primaryKey: String = ""
    @objc dynamic var contract: String = Constants.nullAddress.eip55String
    @objc dynamic var tokenContract: String = Constants.nullAddress.eip55String
    @objc dynamic var chainId: Int = 0
    @objc dynamic var eventName: String = ""
    @objc dynamic var blockNumber: Int = 0
    @objc dynamic var logIndex: Int = 0
    @objc dynamic var filter: String = ""
    @objc dynamic var json: String = "{}" {
        didSet {
            _data = EventInstance.convertJsonToDictionary(json)
        }
    }

    //Needed because Realm objects' properties (`json`) don't fire didSet after the object has been written to the database
    var _data: [String: AssetInternalValue]?
    var data: [String: AssetInternalValue] {
        if let _data = _data {
            return _data
        } else {
            let value = EventInstance.convertJsonToDictionary(json)
            _data = value
            return value
        }
    }

    convenience init(contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String, blockNumber: Int, logIndex: Int, filter: String, json: String) {
        self.init()
        self.primaryKey = EventInstance.generatePrimaryKey(fromContract: contract, tokenContract: tokenContract, server: server, eventName: eventName, blockNumber: blockNumber, logIndex: logIndex, filter: filter)
        self.contract = contract.eip55String
        self.tokenContract = tokenContract.eip55String
        self.chainId = server.chainID
        self.eventName = eventName
        self.blockNumber = blockNumber
        self.logIndex = logIndex
        self.filter = filter
        self.json = json
        self._data = EventInstance.convertJsonToDictionary(json)
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

