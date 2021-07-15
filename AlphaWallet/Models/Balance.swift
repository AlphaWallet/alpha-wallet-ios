// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation

struct Balance: BalanceProtocol {

    let value: BigInt

    init(value: BigInt) {
        self.value = value
    }

    var isZero: Bool {
        return value.isZero
    }

    var amountShort: String {
        return EtherNumberFormatter.short.string(from: value)
    }

    var amountFull: String {
        return EtherNumberFormatter.full.string(from: value)
    }
}

struct ERC20Balance: BalanceProtocol {

    let value: BigInt
    private let decimals: Int

    init(tokenObject: TokenObject) {
        value = tokenObject.valueBigInt
        decimals = tokenObject.decimals
    }

    var isZero: Bool {
        return value.isZero
    }

    var amountShort: String {
        return EtherNumberFormatter.short.string(from: value, decimals: decimals).droppedTrailingZeros
    }

    var amountFull: String {
        return EtherNumberFormatter.plain.string(from: value, decimals: decimals).droppedTrailingZeros
    }
}
