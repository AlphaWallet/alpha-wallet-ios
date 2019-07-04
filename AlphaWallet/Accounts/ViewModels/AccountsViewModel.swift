// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct AccountsViewModel {
    let hdWallets: [Wallet]
    let keystoreWallets: [Wallet]
    let watchedWallets: [Wallet]

    init(hdWallets: [Wallet], keystoreWallets: [Wallet], watchedWallets: [Wallet]) {
        self.hdWallets = hdWallets
        self.keystoreWallets = keystoreWallets
        self.watchedWallets = watchedWallets
    }

    var title: String {
        return R.string.localizable.walletNavigationTitle()
    }
}
