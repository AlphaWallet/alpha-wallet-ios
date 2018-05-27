// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore
import UIKit

struct AccountViewModel {
    let wallet: Wallet
    let current: Wallet?
    let walletBalance: Balance?
    init(wallet: Wallet, current: Wallet?, walletBalance: Balance?) {
        self.wallet = wallet
        self.current = current
        self.walletBalance = walletBalance
    }
    var showWatchIcon: Bool {
        return wallet.type == .watch(wallet.address)
    }
    var balance: String {
        let amount = walletBalance?.amountFull ?? "--"
        return "\(amount) ETH"
    }
    var address: String {
        return wallet.address.description
    }
    var showActiveIcon: Bool {
        return wallet == current
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var contentsBackgroundColor: UIColor {
        return backgroundColor
    }

    var contentsBorderColor: UIColor {
        return Colors.appHighlightGreen
    }

    var contentsBorderWidth: CGFloat {
        return 1
    }

    var balanceFont: UIFont {
        return Fonts.light(size: 20)!
    }

    var addressFont: UIFont {
        return Fonts.semibold(size: 12)!
    }

    var addressTextColor: UIColor {
        return Colors.gray
    }
}
