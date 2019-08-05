// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt
import Kanna

//Origin's output type
enum OriginAsType: String {
    case address
    case uint
    case uint8
    case uint16
    case uint24
    case uint32
    case uint40
    case uint48
    case uint56
    case uint64
    case uint72
    case uint80
    case uint88
    case uint96
    case uint104
    case uint112
    case uint120
    case uint128
    case uint136
    case uint144
    case uint152
    case uint160
    case uint168
    case uint176
    case uint184
    case uint192
    case uint200
    case uint208
    case uint216
    case uint224
    case uint232
    case uint240
    case uint248
    case uint256
    case int
    case int8
    case int16
    case int24
    case int32
    case int40
    case int48
    case int56
    case int64
    case int72
    case int80
    case int88
    case int96
    case int104
    case int112
    case int120
    case int128
    case int136
    case int144
    case int152
    case int160
    case int168
    case int176
    case int184
    case int192
    case int200
    case int208
    case int216
    case int224
    case int232
    case int240
    case int248
    case int256
    case utf8
    case e18
    case e8
    case bytes
    case bytes1
    case bytes2
    case bytes3
    case bytes4
    case bytes5
    case bytes6
    case bytes7
    case bytes8
    case bytes9
    case bytes10
    case bytes11
    case bytes12
    case bytes13
    case bytes14
    case bytes15
    case bytes16
    case bytes17
    case bytes18
    case bytes19
    case bytes20
    case bytes21
    case bytes22
    case bytes23
    case bytes24
    case bytes25
    case bytes26
    case bytes27
    case bytes28
    case bytes29
    case bytes30
    case bytes31
    case bytes32
    case bool
    case string
    case void

    var solidityReturnType: SolidityType {
        switch self {
        case .address:
            return .address
        case .uint:
            return .uint256
        case .utf8:
            return .string
        case .e18, .e8:
            return .uint256
        case .bytes:
            return .bytes
        case .string:
            return .string
        case .bool:
            return .bool
        case .void:
            return .void
        case .uint8:
            return .uint8
        case .uint16:
            return .uint16
        case .uint24:
            return .uint24
        case .uint32:
            return .uint32
        case .uint40:
            return .uint40
        case .uint48:
            return .uint48
        case .uint56:
            return .uint56
        case .uint64:
            return .uint64
        case .uint72:
            return .uint72
        case .uint80:
            return .uint80
        case .uint88:
            return .uint88
        case .uint96:
            return .uint96
        case .uint104:
            return .uint104
        case .uint112:
            return .uint112
        case .uint120:
            return .uint120
        case .uint128:
            return .uint128
        case .uint136:
            return .uint136
        case .uint144:
            return .uint144
        case .uint152:
            return .uint152
        case .uint160:
            return .uint160
        case .uint168:
            return .uint168
        case .uint176:
            return .uint176
        case .uint184:
            return .uint184
        case .uint192:
            return .uint192
        case .uint200:
            return .uint200
        case .uint208:
            return .uint208
        case .uint216:
            return .uint216
        case .uint224:
            return .uint224
        case .uint232:
            return .uint232
        case .uint240:
            return .uint240
        case .uint248:
            return .uint248
        case .uint256:
            return .uint256
        case .int:
            return .int
        case .int8:
            return .int8
        case .int16:
            return .int16
        case .int24:
            return .int24
        case .int32:
            return .int32
        case .int40:
            return .int40
        case .int48:
            return .int48
        case .int56:
            return .int56
        case .int64:
            return .int64
        case .int72:
            return .int72
        case .int80:
            return .int80
        case .int88:
            return .int88
        case .int96:
            return .int96
        case .int104:
            return .int104
        case .int112:
            return .int112
        case .int120:
            return .int120
        case .int128:
            return .int128
        case .int136:
            return .int136
        case .int144:
            return .int144
        case .int152:
            return .int152
        case .int160:
            return .int160
        case .int168:
            return .int168
        case .int176:
            return .int176
        case .int184:
            return .int184
        case .int192:
            return .int192
        case .int200:
            return .int200
        case .int208:
            return .int208
        case .int216:
            return .int216
        case .int224:
            return .int224
        case .int232:
            return .int232
        case .int240:
            return .int240
        case .int248:
            return .int248
        case .int256:
            return .int256
        case .bytes1:
            return .bytes1
        case .bytes2:
            return .bytes2
        case .bytes3:
            return .bytes3
        case .bytes4:
            return .bytes4
        case .bytes5:
            return .bytes5
        case .bytes6:
            return .bytes6
        case .bytes7:
            return .bytes7
        case .bytes8:
            return .bytes8
        case .bytes9:
            return .bytes9
        case .bytes10:
            return .bytes10
        case .bytes11:
            return .bytes11
        case .bytes12:
            return .bytes12
        case .bytes13:
            return .bytes13
        case .bytes14:
            return .bytes14
        case .bytes15:
            return .bytes15
        case .bytes16:
            return .bytes16
        case .bytes17:
            return .bytes17
        case .bytes18:
            return .bytes18
        case .bytes19:
            return .bytes19
        case .bytes20:
            return .bytes20
        case .bytes21:
            return .bytes21
        case .bytes22:
            return .bytes22
        case .bytes23:
            return .bytes23
        case .bytes24:
            return .bytes24
        case .bytes25:
            return .bytes25
        case .bytes26:
            return .bytes26
        case .bytes27:
            return .bytes27
        case .bytes28:
            return .bytes28
        case .bytes29:
            return .bytes29
        case .bytes30:
            return .bytes30
        case .bytes31:
            return .bytes31
        case .bytes32:
            return .bytes32
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
