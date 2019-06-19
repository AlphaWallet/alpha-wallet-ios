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
        case .e18:
            return .uint256
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

    private var originElement: XMLElement {
        switch self {
        case .tokenId(let origin):
            return origin.originElement
        case .function(let origin):
            return origin.originElement
        case .userEntry(let origin):
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
        }
    }
    var userEntryId: AttributeId? {
        switch self {
        case .tokenId, .function:
            return nil
        case .userEntry(let origin):
            return origin.attributeId
        }
    }
    var isImmediatelyAvailable: Bool {
        switch self {
        case .tokenId, .userEntry:
            return true
        case .function:
            return false
        }
    }

    init?(forTokenIdElement tokenIdElement: XMLElement, xmlContext: XmlContext) {
        guard let bitmask = XMLHandler.getBitMask(fromTokenIdElement: tokenIdElement) else { return nil }
        guard let asType = tokenIdElement["as"].flatMap({ OriginAsType(rawValue: $0) }) else { return nil }

        let bitShift = Origin.bitShiftCount(forBitMask: bitmask)
        self = .tokenId(.init(originElement: tokenIdElement, xmlContext: xmlContext, bitmask: bitmask, bitShift: bitShift, asType: asType))
    }

    init?(forEthereumFunctionElement ethereumFunctionElement: XMLElement, attributeId: AttributeId, originContract: AlphaWallet.Address, xmlContext: XmlContext) {
        guard let result = FunctionOrigin(forEthereumFunctionCallElement: ethereumFunctionElement, attributeId: attributeId, originContract: originContract, xmlContext: xmlContext) else { return nil }
        self = .function(result)
    }

    init?(forUserEntryElement userEntryElement: XMLElement, attributeId: AttributeId, xmlContext: XmlContext) {
        guard let asType = userEntryElement["as"].flatMap({ OriginAsType(rawValue: $0) }) else { return nil }

        self = .userEntry(.init(originElement: userEntryElement, xmlContext: xmlContext, attributeId: attributeId, asType: asType))
    }

    ///Used to truncate bits to the right of the bitmask
    private static func bitShiftCount(forBitMask bitmask: BigUInt) -> Int {
        var count = 0
        repeat {
            count += 1
        } while bitmask % (1 << count) == 0
        return count - 1
    }

    func extractValue(fromTokenId tokenId: TokenId, inWallet account: Wallet, server: RPCServer, callForAssetAttributeCoordinator: CallForAssetAttributeCoordinator, userEntryValues: [AttributeId: String], tokenLevelNonSubscribableAttributesAndValues: [AttributeId: AssetInternalValue]) -> AssetInternalValue? {
        switch self {
        case .tokenId(let origin):
            return origin.extractValue(fromTokenId: tokenId)
        case .function(let origin):
            //We don't pass in attributes with function-origins because the order is undefined at the moment
            return origin.extractValue(withTokenId: tokenId, account: account, server: server, attributeAndValues: tokenLevelNonSubscribableAttributesAndValues, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator)
        case .userEntry(let origin):
            guard let input = userEntryValues[origin.attributeId] else { return nil }
            return origin.extractValue(fromUserEntry: input)
        }
    }

    func extractMapping() -> AssetAttributeMapping? {
        guard let element = XMLHandler.getMappingElement(fromOriginElement: originElement, xmlContext: xmlContext) else { return nil }
        return .init(mapping: element, xmlContext: xmlContext)
    }
}
