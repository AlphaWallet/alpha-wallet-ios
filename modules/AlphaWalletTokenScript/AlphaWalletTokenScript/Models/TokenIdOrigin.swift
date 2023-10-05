// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import AlphaWalletCore
import AlphaWalletWeb3
import BigInt
import Kanna

public struct TokenIdOrigin {
    private let bitmask: BigUInt
    private let bitShift: Int
    private let asType: OriginAsType

    public let originElement: XMLElement
    public let xmlContext: XmlContext

    public init(originElement: XMLElement, xmlContext: XmlContext, bitmask: BigUInt, bitShift: Int, asType: OriginAsType) {
        self.originElement = originElement
        self.xmlContext = xmlContext
        self.bitmask = bitmask
        self.bitShift = bitShift
        self.asType = asType
    }

    public func extractValue(fromTokenId tokenId: TokenId) -> AssetInternalValue? {
        let number: BigUInt = (`bitmask` & tokenId) >> bitShift
        switch asType {
        case .address:
            return String(numberEncodingUtf8String: number).flatMap { AlphaWallet.Address(string: $0) }.flatMap { .address($0) }
        case .uint:
            return .uint(number)
        case .utf8:
            return String(numberEncodingUtf8String: number).flatMap { .string($0) }
        case .e18:
            return EtherNumberFormatter().number(from: String(number)).flatMap { .uint(BigUInt($0)) }
        case .e8:
            return EtherNumberFormatter().number(from: String(number), decimals: 8).flatMap { .uint(BigUInt($0)) }
        case .e6:
            return EtherNumberFormatter().number(from: String(number), decimals: 6).flatMap { .uint(BigUInt($0)) }
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
    public init?(numberEncodingUtf8String number: BigUInt) {
        self.init(data: Data(bytes: String(number, radix: 16).hexToBytes), encoding: .utf8)
    }
}
