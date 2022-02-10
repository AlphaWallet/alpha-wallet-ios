//
//  Alert.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import UIKit

enum PriceTarget: String, Codable {
    case above
    case below

    var title: String {
        switch self {
        case .above:
            return R.string.localizable.priceAlertAbove()
        case .below:
            return R.string.localizable.priceAlertBelow()
        }
    }
}

enum AlertType: Codable {
    private enum CodingKeys: String, CodingKey {
        case priceTarget
        case value
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .price(let priceTarget, let value):
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(priceTarget, forKey: .priceTarget)
            try container.encode(value, forKey: .value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let priceTarget: PriceTarget = container.decode(PriceTarget.self, forKey: .priceTarget, defaultValue: PriceTarget.above)
        let value: Double = container.decode(Double.self, forKey: .value, defaultValue: 0.0)

        self = .price(priceTarget: priceTarget, value: value)
    }

    case price(priceTarget: PriceTarget, value: Double)

    init(value: Double, marketPrice: Double) {
        let priceTarget: PriceTarget = value > marketPrice ? .above : .below
        self = .price(priceTarget: priceTarget, value: value)
    }

    var icon: UIImage? {
        switch self {
        case .price(let priceTarget, _):
            switch priceTarget {
            case .above:
                return R.image.iconsSystemUp()
            case .below:
                return R.image.iconsSystemDown()
            }
        }
    }

    var title: String {
        switch self {
        case .price(let priceTarget, let value):
            let result = Formatter.fiat.string(from: value) ?? "-"
            return "\(priceTarget.title) \(result)"
        }
    }
}

struct PriceAlert: Codable, Equatable {
    var type: AlertType
    var isEnabled: Bool
    let addressAndRPCServer: AddressAndRPCServer
    var icon: UIImage? {
        return type.icon
    }

    var title: String {
        return type.title
    }

    init(type: AlertType, tokenObject: TokenObject, isEnabled: Bool) {
        self.addressAndRPCServer = tokenObject.addressAndRPCServer
        self.type = type
        self.isEnabled = isEnabled
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.addressAndRPCServer == rhs.addressAndRPCServer
    }

    var description: String {
        type.title
    }

}

