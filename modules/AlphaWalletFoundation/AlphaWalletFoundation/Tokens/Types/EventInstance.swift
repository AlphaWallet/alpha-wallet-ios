// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import AlphaWalletTokenScript
import RealmSwift

class EventInstance: Object {
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

    convenience init(event: EventInstanceValue) {
        self.init()

        self.primaryKey = event.primaryKey
        self.contract = event.contract
        self.tokenContract = event.tokenContract
        self.chainId = event.chainId
        self.eventName = event.eventName
        self.blockNumber = event.blockNumber
        self.logIndex = event.logIndex
        self.filter = event.filter
        self.json = event.json
        self._data = event._data
    }

    public override static func primaryKey() -> String? {
        return "primaryKey"
    }

    public override static func ignoredProperties() -> [String] {
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

extension EventInstanceValue {
    init(event: EventInstance) {
        self.init(primaryKey: event.primaryKey, contract: event.contract, tokenContract: event.tokenContract, chainId: event.chainId, eventName: event.eventName, blockNumber: event.blockNumber, logIndex: event.logIndex, filter: event.filter, json: event.json, data: event._data)

    }
}
