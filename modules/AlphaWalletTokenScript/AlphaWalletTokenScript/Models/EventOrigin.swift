// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import Kanna

public struct EventParameter {
    public let name: String
    public let type: String
    public let isIndexed: Bool

    ///RPC API for fetching events doesn't accept uint (and probably int). Instead it wants `uint256`
    public var typeAppropriateForAbi: String {
        switch type {
        case "uint":
            return "uint256"
        case "int":
            return "int256"
        default:
            return type
        }
    }

    public init(name: String, type: String, isIndexed: Bool) {
        self.name = name
        self.type = type
        self.isIndexed = isIndexed
    }
}

public struct EventDefinition {
    let contract: AlphaWallet.Address
    let name: String
    let parameters: [EventParameter]

    public init(contract: AlphaWallet.Address, name: String, parameters: [EventParameter]) {
        self.contract = contract
        self.name = name
        self.parameters = parameters
    }
}

public struct EventOrigin {
    private let eventDefinition: EventDefinition
    private let eventParameterName: String?

    public let originElement: XMLElement
    public let xmlContext: XmlContext
    public let eventFilter: (name: String, value: String)

    public var contract: AlphaWallet.Address {
        eventDefinition.contract
    }
    public var eventName: String {
        eventDefinition.name
    }
    public var parameters: [EventParameter] {
        eventDefinition.parameters
    }
    //TODO add test
    //TODO rewrite with Encodable
    public var eventAbiString: String {
        var inputs = [[String: Any]]()
        for each in parameters {
            inputs.append([
                "name": each.name,
                "type": each.typeAppropriateForAbi,
                "indexed": each.isIndexed,
            ])
        }
        let result: [String: Any] = [
            "type": "event",
            "name": eventName,
            "anonymous": false,
            "inputs": inputs
        ]
        let contents = result.jsonString ?? ""
        return "[\(contents)]"
    }
    public var hasEventParameterName: Bool {
        if let eventParameterName = eventParameterName {
            return !eventParameterName.isEmpty
        } else {
            return false
        }
    }

    public init(originElement: XMLElement, xmlContext: XmlContext, eventDefinition: EventDefinition, eventParameterName: String?, eventFilter: (name: String, value: String)) {
        self.originElement = originElement
        self.xmlContext = xmlContext
        self.eventDefinition = eventDefinition
        self.eventParameterName = eventParameterName
        self.eventFilter = eventFilter
    }

    public func extractValue(fromEvent event: EventInstanceValue) -> AssetInternalValue? {
        eventParameterName.flatMap { event._data?[$0] }
    }
}