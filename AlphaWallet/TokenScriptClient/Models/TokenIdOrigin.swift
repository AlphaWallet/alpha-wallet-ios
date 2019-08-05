// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt
import Kanna

struct TokenIdOrigin {
    private let bitmask: BigUInt
    private let bitShift: Int
    private let asType: OriginAsType

    let originElement: XMLElement
    let xmlContext: XmlContext

    init(originElement: XMLElement, xmlContext: XmlContext, bitmask: BigUInt, bitShift: Int, asType: OriginAsType) {
        self.originElement = originElement
        self.xmlContext = xmlContext
        self.bitmask = bitmask
        self.bitShift = bitShift
        self.asType = asType
    }

    func extractValue(fromTokenId tokenId: TokenId) -> AssetInternalValue? {
        let number: BigUInt = (`bitmask` & tokenId) >> bitShift
        switch asType {
        case .address:
            return String(numberEncodingUtf8String: number).flatMap { AlphaWallet.Address(string: $0) }.flatMap { .address($0) }
        case .uint:
            return .uint(number)
        case .utf8, .string:
            return String(numberEncodingUtf8String: number).flatMap { .string($0) }
        case .e18:
            return EtherNumberFormatter().number(from: String(number)).flatMap { .uint(BigUInt($0)) }
        case .e8:
            return EtherNumberFormatter().number(from: String(number), decimals: 8).flatMap { .uint(BigUInt($0)) }
        case .e4:
            return EtherNumberFormatter().number(from: String(number), decimals: 4).flatMap { .uint(BigUInt($0)) }
        case .e2:
            return EtherNumberFormatter().number(from: String(number), decimals: 2).flatMap { .uint(BigUInt($0)) }
        case .bool:
            return .bool(number != 0)
        case .bytes:
            return .bytes(number.serialize())
        case .void:
            return nil
        }
    }
}

extension String {
    init?(numberEncodingUtf8String number: BigUInt) {
        self.init(data: Data(bytes: String(number, radix: 16).hexa2Bytes), encoding: .utf8)
    }
}
