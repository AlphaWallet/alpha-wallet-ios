// Copyright SIX DAY LLC. All rights reserved.

import UIKit

struct NewTokenViewModel {
    var title: String {
        return R.string.localizable.tokensNewtokenNavigationTitle()
    }

    var ERC875TokenBalance: [String] = []

    var ERC875TokenBalanceAmount: Int {
        var balance = 0
        if !ERC875TokenBalance.isEmpty {
            for _ in 0...ERC875TokenBalance.count - 1 {
                balance += 1
            }
        }
        return balance 
    }
    
    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var choiceLabelColor: UIColor {
        return Colors.appGrayLabel
    }

    var choiceLabelFont: UIFont {
        return Fonts.regular(size: 10)
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
