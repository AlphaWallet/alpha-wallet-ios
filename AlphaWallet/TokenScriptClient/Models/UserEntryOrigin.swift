// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt
import Kanna

struct UserEntryOrigin {
    private let asType: OriginAsType

    let originElement: XMLElement
    let xmlContext: XmlContext
    let attributeId: AttributeId
    let bitmask: BigUInt
    let bitShift: Int

    init(originElement: XMLElement, xmlContext: XmlContext, attributeId: AttributeId, asType: OriginAsType, bitmask: BigUInt, bitShift: Int) {
        self.originElement = originElement
        self.xmlContext = xmlContext
        self.attributeId = attributeId
        self.asType = asType
        self.bitmask = bitmask
        self.bitShift = bitShift
    }

    func extractValue(fromUserEntry userEntry: String) -> AssetInternalValue? {
        switch asType {
        case .address:
            return AlphaWallet.Address(string: userEntry.trimmed).flatMap { .address($0) }
        case .uint:
            guard let userEntryNumber = BigUInt(userEntry, radix: 16) else { return BigUInt(userEntry).flatMap { .uint($0) } }
            let number: BigUInt = (bitmask & userEntryNumber) >> bitShift
            return .uint(number)
        case .utf8:
            return .string(userEntry)
        case .bytes:
            guard let userEntryNumber = BigUInt(userEntry, radix: 16) else { return .bytes(Data(bytes: userEntry.drop0x.hexa2Bytes)) }
            let number: BigUInt = (bitmask & userEntryNumber) >> bitShift
            return .bytes(number.serialize())
        case .e18:
            return EtherNumberFormatter().number(from: userEntry).flatMap { .uint(BigUInt($0)) }
        case .e8:
            return EtherNumberFormatter().number(from: userEntry, decimals: 8).flatMap { .uint(BigUInt($0)) }
        case .e6:
            return EtherNumberFormatter().number(from: userEntry, decimals: 6).flatMap { .uint(BigUInt($0)) }
        case .e4:
            return EtherNumberFormatter().number(from: userEntry, decimals: 4).flatMap { .uint(BigUInt($0)) }
        case .e2:
            return EtherNumberFormatter().number(from: userEntry, decimals: 2).flatMap { .uint(BigUInt($0)) }
        case .bool:
            return .bool(userEntry == "true")
        case .void:
            return nil
        }
    }
}
