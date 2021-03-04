//
//  EventInstanceValue.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.01.2021.
//

import UIKit

struct EventInstanceValue {
    var primaryKey: String
    var contract: String
    var tokenContract: String
    var chainId: Int
    var eventName: String
    var blockNumber: Int
    var logIndex: Int
    var filter: String
    var json: String
    var _data: [String: AssetInternalValue]?

    init(contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String, blockNumber: Int, logIndex: Int, filter: String, json: String) {
        self.primaryKey = EventInstance.generatePrimaryKey(fromContract: contract, tokenContract: tokenContract, server: server, eventName: eventName, blockNumber: blockNumber, logIndex: logIndex, filter: filter)
        self.contract = contract.eip55String
        self.tokenContract = tokenContract.eip55String
        self.chainId = server.chainID
        self.eventName = eventName
        self.blockNumber = blockNumber
        self.logIndex = logIndex
        self.filter = filter
        self.json = json
        self._data = EventInstanceValue.convertJsonToDictionary(json)
    }

    init(event: EventInstance) {
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

