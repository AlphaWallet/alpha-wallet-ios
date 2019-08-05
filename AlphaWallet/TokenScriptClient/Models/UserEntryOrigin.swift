// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt
import Kanna

struct UserEntryOrigin {
    private let asType: OriginAsType

    let originElement: XMLElement
    let xmlContext: XmlContext
    let attributeId: AttributeId

    init(originElement: XMLElement, xmlContext: XmlContext, attributeId: AttributeId, asType: OriginAsType) {
        self.originElement = originElement
        self.xmlContext = xmlContext
        self.attributeId = attributeId
        self.asType = asType
    }

    func extractValue(fromUserEntry userEntry: String) -> AssetInternalValue? {
        switch asType {
        case .address:
            return AlphaWallet.Address(string: userEntry.trimmed).flatMap { .address($0) }
        case .uint, .uint8, .uint16, .uint24, .uint32, .uint40, .uint48, .uint56, .uint64, .uint72, .uint80, .uint88, .uint96, .uint104, .uint112, .uint120, .uint128, .uint136, .uint144, .uint152, .uint160, .uint168, .uint176, .uint184, .uint192, .uint200, .uint208, .uint216, .uint224, .uint232, .uint240, .uint248, .uint256:
            return BigUInt(userEntry).flatMap { .uint($0) }
        case .int, .int8, .int16, .int24, .int32, .int40, .int48, .int56, .int64, .int72, .int80, .int88, .int96, .int104, .int112, .int120, .int128, .int136, .int144, .int152, .int160, .int168, .int176, .int184, .int192, .int200, .int208, .int216, .int224, .int232, .int240, .int248, .int256:
            return BigInt(userEntry).flatMap { .int($0) }
        case .utf8, .string:
            return String(data: Data(bytes: userEntry.hexa2Bytes), encoding: .utf8).flatMap { .string($0) }
        case .bytes, .bytes1, .bytes2, .bytes3, .bytes4, .bytes5, .bytes6, .bytes7, .bytes8, .bytes9, .bytes10, .bytes11, .bytes12, .bytes13, .bytes14, .bytes15, .bytes16, .bytes17, .bytes18, .bytes19, .bytes20, .bytes21, .bytes22, .bytes23, .bytes24, .bytes25, .bytes26, .bytes27, .bytes28, .bytes29, .bytes30, .bytes31, .bytes32:
            return .bytes(userEntry)
        case .e18:
            return EtherNumberFormatter().number(from: userEntry).flatMap { .uint(BigUInt($0)) }
        case .e8:
            return EtherNumberFormatter().number(from: userEntry, decimals: 8).flatMap { .uint(BigUInt($0)) }
        case .bool:
            return .bool(userEntry == "true")
        case .void:
            return nil
        }
    }
}
