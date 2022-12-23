// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

struct PromptBackupWalletAfterExceedingThresholdViewViewModel: PromptBackupWalletViewModel {
    private let formatter: NumberFormatter

    let walletAddress: AlphaWallet.Address
    let rate: PromptBackupCoordinator.CurrencyRateForEther

    init(walletAddress: AlphaWallet.Address, rate: PromptBackupCoordinator.CurrencyRateForEther) {
        self.walletAddress = walletAddress
        self.rate = rate
        self.formatter = NumberFormatter.fiat(currency: rate.currency)
    }

    var backgroundColor: UIColor {
        return .init(red: 183, green: 80, blue: 70)
    }

    var title: String {
        return R.string.localizable.backupPromptAfterHittingThresholdTitle()
    }

    var description: String {
        let prettyAmount = formatter.string(double: rate.value.doubleValue) ?? "-"
        return R.string.localizable.backupPromptAfterHittingThresholdDescription(prettyAmount)
    }

    var backupButtonBackgroundColor: UIColor {
        return UIColor(red: 119, green: 56, blue: 50)
    }
}
