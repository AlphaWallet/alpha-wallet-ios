// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct AccountsViewModel {
    private var config: Config

    let hdWallets: [Wallet]
    let keystoreWallets: [Wallet]
    let watchedWallets: [Wallet]

    init(config: Config, hdWallets: [Wallet], keystoreWallets: [Wallet], watchedWallets: [Wallet]) {
        self.config = config
        self.hdWallets = hdWallets
        self.keystoreWallets = keystoreWallets
        self.watchedWallets = watchedWallets
    }

    var title: String {
        return R.string.localizable.walletNavigationTitle()
    }

    func walletName(forAccount account: Wallet) -> String? {
        let walletNames = config.walletNames
        return walletNames[account.address]
    }
}
