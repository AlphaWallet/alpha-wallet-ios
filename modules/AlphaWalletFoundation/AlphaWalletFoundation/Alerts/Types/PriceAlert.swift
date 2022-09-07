//
//  Alert.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import Foundation

public enum PriceTarget: String, Codable {
    case above
    case below
}

public enum AlertType: Codable {
    private enum CodingKeys: String, CodingKey {
        case priceTarget
        case value
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .price(let priceTarget, let value):
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(priceTarget, forKey: .priceTarget)
            try container.encode(value, forKey: .value)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let priceTarget: PriceTarget = container.decode(PriceTarget.self, forKey: .priceTarget, defaultValue: PriceTarget.above)
        let value: Double = container.decode(Double.self, forKey: .value, defaultValue: 0.0)

        self = .price(priceTarget: priceTarget, value: value)
    }

    case price(priceTarget: PriceTarget, value: Double)

    public init(value: Double, marketPrice: Double) {
        let priceTarget: PriceTarget = value > marketPrice ? .above : .below
        self = .price(priceTarget: priceTarget, value: value)
    }
}

public struct PriceAlert: Codable, Equatable {
    public var type: AlertType
    public var isEnabled: Bool
    public let addressAndRPCServer: AddressAndRPCServer

    public init(type: AlertType, token: Token, isEnabled: Bool) {
        self.addressAndRPCServer = token.addressAndRPCServer
        self.type = type
        self.isEnabled = isEnabled
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.addressAndRPCServer == rhs.addressAndRPCServer
    }
}
