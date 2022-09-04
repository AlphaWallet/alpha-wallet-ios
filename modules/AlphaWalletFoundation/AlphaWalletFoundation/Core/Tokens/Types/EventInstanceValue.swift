//
//  EventInstanceValue.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 13.01.2021.
//

import Foundation

public struct EventInstanceValue {
    public var primaryKey: String
    public var contract: String
    public var tokenContract: String
    public var chainId: Int
    public var eventName: String
    public var blockNumber: Int
    public var logIndex: Int
    public var filter: String
    public var json: String
    public var _data: [String: AssetInternalValue]?

    public init(contract: AlphaWallet.Address, tokenContract: AlphaWallet.Address, server: RPCServer, eventName: String, blockNumber: Int, logIndex: Int, filter: String, json: String) {
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
}
