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

    var actionButtonCornerRadius: CGFloat {
        return 16
    }

    var actionButtonShadowColor: UIColor {
        return .black
    }

    var actionButtonShadowOffset: CGSize {
        return .init(width: 1, height: 2)
    }

    var actionButtonShadowOpacity: Float {
        return 0.3
    }

    var actionButtonShadowRadius: CGFloat {
        return 5
    }
}
