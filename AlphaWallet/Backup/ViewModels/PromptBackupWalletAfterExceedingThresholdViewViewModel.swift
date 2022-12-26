// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

struct PromptBackupWalletAfterExceedingThresholdViewViewModel: PromptBackupWalletViewModel {
    private let formatter: NumberFormatter

    let walletAddress: AlphaWallet.Address
    let balance: WalletBalance.ValueForCurrency

    init(walletAddress: AlphaWallet.Address, balance: WalletBalance.ValueForCurrency) {
        self.walletAddress = walletAddress
        self.balance = balance
        self.formatter = NumberFormatter.fiat(currency: balance.currency)
    }

    var backgroundColor: UIColor {
        return .init(red: 183, green: 80, blue: 70)
    }

    var title: String {
        return R.string.localizable.backupPromptAfterHittingThresholdTitle()
    }

    var description: String {
        let prettyAmount = formatter.string(double: balance.amount) ?? "-"
        return R.string.localizable.backupPromptAfterHittingThresholdDescription(prettyAmount)
    }

    var backupButtonBackgroundColor: UIColor {
        return UIColor(red: 119, green: 56, blue: 50)
    }
}
