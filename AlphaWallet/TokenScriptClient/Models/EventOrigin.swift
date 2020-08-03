// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import Kanna

struct EventParameter {
    let name: String
    let type: String
    let isIndexed: Bool

    ///RPC API for fetching events doesn't accept uint (and probably int). Instead it wants `uint256`
    var typeAppropriateForAbi: String {
        switch type {
        case "uint":
            return "uint256"
        case "int":
            return "int256"
        default:
            return type
        }
    }
}

struct EventDefinition {
    let contract: AlphaWallet.Address
    let name: String
    let parameters: [EventParameter]
}

struct EventOrigin {
    private let eventDefinition: EventDefinition
    private let eventParameterName: String?

    let originElement: XMLElement
    let xmlContext: XmlContext
    let eventFilter: (name: String, value: String)

    var contract: AlphaWallet.Address {
        eventDefinition.contract
    }
    var eventName: String {
        eventDefinition.name
    }
    var parameters: [EventParameter] {
        eventDefinition.parameters
    }
    //TODO add test
    //TODO rewrite with Encodable
    var eventAbiString: String {
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
    var hasEventParameterName: Bool {
        if let eventParameterName = eventParameterName {
            return !eventParameterName.isEmpty
        } else {
            return false
        }
    }

    init(originElement: XMLElement, xmlContext: XmlContext, eventDefinition: EventDefinition, eventParameterName: String?, eventFilter: (name: String, value: String)) {
        self.originElement = originElement
        self.xmlContext = xmlContext
        self.eventDefinition = eventDefinition
        self.eventParameterName = eventParameterName
        self.eventFilter = eventFilter
    }

    func extractValue(fromEvent event: EventInstance) -> AssetInternalValue? {
        eventParameterName.flatMap { event.data[$0] }
    }
}
