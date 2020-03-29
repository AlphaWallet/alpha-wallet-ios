// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct BalanceTokenViewModel: BalanceBaseViewModel {
    let token: TokenObject

    var currencyAmount: String? {
        return nil
    }

    var amountFull: String {
        return EtherNumberFormatter.full.string(from: token.valueBigInt, decimals: token.decimals)
    }

    var amountShort: String {
        return EtherNumberFormatter.short.string(from: token.valueBigInt, decimals: token.decimals)
    }

    var name: String {
        return token.name
    }

    var symbol: String {
        return token.symbol
    }
}
