// Copyright SIX DAY LLC. All rights reserved.

import UIKit

struct NewTokenViewModel {
    var title: String {
        return R.string.localizable.tokensNewtokenNavigationTitle()
    }

    var stormBirdBalance: [String] = []

    var stormBirdBalanceAsInt: Int {
        var balance = 0
        if !stormBirdBalance.isEmpty {
            for _ in 0...stormBirdBalance.count - 1 {
                balance += 1
            }
        }
        return balance
    }
    
    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var choiceLabelColor: UIColor {
        return Colors.appGrayLabelColor
    }

    var choiceLabelFont: UIFont {
        return Fonts.regular(size: 10)!
    }

    var addressLabel: String {
        return R.string.localizable.contractAddress().uppercased()
    }

    var symbolLabel: String {
        return R.string.localizable.symbol().uppercased()
    }

    var decimalsLabel: String {
        return R.string.localizable.decimals().uppercased()
    }

    var balanceLabel: String {
        return R.string.localizable.balance().uppercased()
    }

    var nameLabel: String {
        return R.string.localizable.name().uppercased()
    }

    var buttonTitleColor: UIColor {
        return Colors.appWhite
    }

    var buttonBackgroundColor: UIColor {
        return Colors.appHighlightGreen
    }

    var buttonFont: UIFont {
        return Fonts.regular(size: 20)!
    }
}
