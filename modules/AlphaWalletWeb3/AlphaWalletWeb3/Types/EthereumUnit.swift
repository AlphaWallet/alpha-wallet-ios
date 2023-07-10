// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public enum EthereumUnit: Int {
    case wei = 1
    case kwei = 1_000
    case gwei = 1_000_000_000
    case szabo = 1_000_000_000_000
    case finney = 1_000_000_000_000_000
    case ether = 1_000_000_000_000_000_000

    public var decimals: Int {
        switch self {
        case .wei: return 1
        case .kwei: return 3
        case .gwei: return 9
        case .szabo: return 13
        case .finney: return 15
        case .ether: return 18
        }
    }
}

extension EthereumUnit {
    public var name: String {
        switch self {
        case .wei: return "Wei"
        case .kwei: return "Kwei"
        case .gwei: return "Gwei"
        case .szabo: return "Szabo"
        case .finney: return "Finney"
        case .ether: return "Ether"
        }
    }
}

//https://github.com/ethereumjs/ethereumjs-units/blob/master/units.json
extension EthereumUnit {
    public static var eip1559FeeUnits: EthereumUnit { EthereumUnit.gwei }
}

