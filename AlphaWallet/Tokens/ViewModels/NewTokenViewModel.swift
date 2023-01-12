// Copyright SIX DAY LLC. All rights reserved.

import UIKit

struct NewTokenViewModel {
    var title: String {
        return R.string.localizable.tokensNewtokenNavigationTitle()
    }

    var erc875TokenBalance: [String] = []

    var erc875TokenBalanceAmount: Int {
        var balance = 0
        if !erc875TokenBalance.isEmpty {
            for _ in 0...erc875TokenBalance.count - 1 {
                balance += 1
            }
        }
        return balance
    }

    var addressLabel: String {
        return R.string.localizable.contractAddress()
    }

    var symbolLabel: String {
        return R.string.localizable.symbol()
    }

    var decimalsLabel: String {
        return R.string.localizable.decimals()
    }

    var balanceLabel: String {
        return R.string.localizable.balance()
    }

    var nameLabel: String {
        return R.string.localizable.name()
    }
}
