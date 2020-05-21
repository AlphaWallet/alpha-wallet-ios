// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt
import Kanna

//Origin's output type
enum OriginAsType: String {
    case address
    case uint
    case utf8
    case e18
    case e8
    case e6
    case e4
    case e2
    case bytes
    case bool
    case void

    var solidityReturnType: SolidityType {
        switch self {
        case .address:
            return .address
        case .uint:
            return .uint256
        case .utf8:
            return .string
        case .e18, .e8, .e6, .e4, .e2:
            return .uint256
        case .bytes:
            return .bytes
        case .bool:
            return .bool
        case .void:
            return .void
        }
    }
}

enum Origin {
    case tokenId(TokenIdOrigin)
    case function(FunctionOrigin)
    case userEntry(UserEntryOrigin)
    case event(EventOrigin)

    private var originElement: XMLElement {
        switch self {
        case .tokenId(let origin):
            return origin.originElement
        case .function(let origin):
            return origin.originElement
        case .userEntry(let origin):
            return origin.originElement
        case .event(let origin):
            return origin.originElement
        }
    }
    private var xmlContext: XmlContext {
        switch self {
        case .tokenId(let origin):
            return origin.xmlContext
        case .function(let origin):
            return origin.xmlContext
        case .userEntry(let origin):
            return origin.xmlContext
        case .event(let origin):
            return origin.xmlContext
        }
    }
    var userEntryId: AttributeId? {
        switch self {
        case .tokenId, .function, .event:
            return nil
        case .userEntry(let origin):
            return origin.attributeId
        }
    }
    var isImmediatelyAvailable: Bool {
        switch self {
        case .tokenId, .userEntry, .event:
            return true
        case .function:
            return false
        }
    }

    init?(forTokenIdElement tokenIdElement: XMLElement, xmlContext: XmlContext) {
        let bitmask = XMLHandler.getBitMask(fromTokenIdElement: tokenIdElement) ?? TokenScript.defaultBitmask
        guard let asType = tokenIdElement["as"].flatMap({ OriginAsType(rawValue: $0) }) else { return nil }
        let bitShift = Origin.bitShiftCount(forBitMask: bitmask)
        self = .tokenId(.init(originElement: tokenIdElement, xmlContext: xmlContext, bitmask: bitmask, bitShift: bitShift, asType: asType))
    }

    init?(forEthereumFunctionElement ethereumFunctionElement: XMLElement, root: XMLDocument, attributeName: AttributeId, originContract: AlphaWallet.Address, xmlContext: XmlContext) {
        let bitmask = XMLHandler.getBitMask(fromTokenIdElement: ethereumFunctionElement) ?? TokenScript.defaultBitmask
        let bitShift = Origin.bitShiftCount(forBitMask: bitmask)
        guard let result = FunctionOrigin(forEthereumFunctionCallElement: ethereumFunctionElement, root: root, attributeName: attributeName, originContract: originContract, xmlContext: xmlContext, bitmask: bitmask, bitShift: bitShift) else { return nil }
        self = .function(result)
    }

    init?(forUserEntryElement userEntryElement: XMLElement, attributeName: AttributeId, xmlContext: XmlContext) {
        let bitmask = XMLHandler.getBitMask(fromTokenIdElement: userEntryElement) ?? TokenScript.defaultBitmask
        let bitShift = Origin.bitShiftCount(forBitMask: bitmask)
        guard let asType = userEntryElement["as"].flatMap({ OriginAsType(rawValue: $0) }) else { return nil }
        self = .userEntry(.init(originElement: userEntryElement, xmlContext: xmlContext, attributeId: attributeName, asType: asType, bitmask: bitmask, bitShift: bitShift))
    }

    init?(forEthereumEventElement eventElement: XMLElement, sourceContractElement: XMLElement, xmlContext: XmlContext) {
        guard let eventParameterName = XMLHandler.getEventParameterName(fromEthereumEventElement: eventElement) else { return nil }
        guard let eventFilter = XMLHandler.getEventFilter(fromEthereumEventElement: eventElement) else { return nil }
        guard let eventDefinition = XMLHandler.getEventDefinition(fromContractElement: sourceContractElement, xmlContext: xmlContext) else { return nil }
        self = .event(.init(originElement: eventElement, xmlContext: xmlContext, eventDefinition: eventDefinition, eventParameterName: eventParameterName, eventFilter: eventFilter))
    }

    ///Used to truncate bits to the right of the bitmask
    private static func bitShiftCount(forBitMask bitmask: BigUInt) -> Int {
        var count = 0
        repeat {
            count += 1
        } while bitmask % (1 << count) == 0
        return count - 1
    }

    func extractValue(fromTokenIdOrEvent tokenIdOrEvent: TokenIdOrEvent, inWallet account: Wallet, server: RPCServer, callForAssetAttributeCoordinator: CallForAssetAttributeCoordinator, userEntryValues: [AttributeId: String], tokenLevelNonSubscribableAttributesAndValues: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue]) -> AssetInternalValue? {
        switch self {
        case .tokenId(let origin):
            return origin.extractValue(fromTokenId: tokenIdOrEvent.tokenId)
        case .function(let origin):
            //We don't pass in attributes with function-origins because the order is undefined at the moment
            return origin.extractValue(withTokenId: tokenIdOrEvent.tokenId, account: account, server: server, attributeAndValues: tokenLevelNonSubscribableAttributesAndValues, localRefs: localRefs, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator)
        case .userEntry(let origin):
            guard let input = userEntryValues[origin.attributeId] else { return nil }
            return origin.extractValue(fromUserEntry: input)
        case .event(let origin):
            switch tokenIdOrEvent {
            case .tokenId:
                return nil
            case .event(_, event: let event):
                return origin.extractValue(fromEvent: event)
            }
        }
    }

    func extractMapping() -> AssetAttributeMapping? {
        guard let element = XMLHandler.getMappingElement(fromOriginElement: originElement, xmlContext: xmlContext) else { return nil }
        return .init(mapping: element, xmlContext: xmlContext)
    }
}
