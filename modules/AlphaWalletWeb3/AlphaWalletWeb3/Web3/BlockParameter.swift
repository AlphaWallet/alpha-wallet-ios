//
//  BlockParameter.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.12.2022.
//

import Foundation
import AlphaWalletCore

public enum BlockParameter: RawRepresentable, Codable {
    public typealias RawValue = String

    case blockNumber(value: Int)
    case earliest
    case latest
    case pending

    public init?(rawValue: String) {
        return nil
    }

    public var rawValue: RawValue {
        switch self {
        case .blockNumber(let value):
            return String(value, radix: 16).add0x
        case .earliest:
            return "earliest"
        case .latest:
            return "latest"
        case .pending:
            return "pending"
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

}