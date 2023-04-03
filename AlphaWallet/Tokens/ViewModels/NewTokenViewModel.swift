// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import AlphaWalletFoundation

struct NewTokenViewModel {
    var title: String {
        return R.string.localizable.tokensNewtokenNavigationTitle()
    }

    var nonFungibleBalance: NonFungibleBalance?

    var nonFungibleBalanceAmount: Int {
        guard let balance = nonFungibleBalance else { return 0 }
        return balance.rawValue.count
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
