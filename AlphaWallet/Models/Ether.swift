// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt

public struct Ether {
    let ether: BigInt

    init?(string: String) {
        guard let value = EtherNumberFormatter().number(from: string) else { return nil }
        ether = value
    }

    init(bigInt: BigInt) {
        ether = bigInt
    }

    static var zero: Ether {
        return .init(bigInt: 0)
    }
}

extension Ether: CustomStringConvertible {
    public var description: String {
        return unformattedDescription
    }

    public var formattedDescription: String {
        return EtherNumberFormatter().string(from: ether)
    }

    public var unformattedDescription: String {
        let formatter = EtherNumberFormatter()
        formatter.groupingSeparator = ""
        return formatter.string(from: ether)
    }
}

extension Ether: LosslessStringConvertible {
    public init?(_ description: String) {
        self.init(string: description)
    }
}

public func *(ether: Ether, num: Int) -> Ether {
    return Ether(bigInt: ether.ether * BigInt(num))
}

public func /(ether: Ether, num: Int) -> Ether {
    return Ether(bigInt: ether.ether / BigInt(num))
}
