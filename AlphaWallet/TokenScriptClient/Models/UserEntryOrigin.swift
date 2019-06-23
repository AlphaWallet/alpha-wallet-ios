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
        case .uint:
            return BigUInt(userEntry).flatMap { .uint($0) }
        case .utf8:
            return String(data: Data(bytes: userEntry.hexa2Bytes), encoding: .utf8).flatMap { .string($0) }
        case .e18:
            return EtherNumberFormatter().number(from: userEntry).flatMap { .uint(BigUInt($0)) }
        case .bool:
            return .bool(userEntry == "true")
        case .void:
            return nil
        }
    }
}
