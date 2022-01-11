// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

struct PromptBackupWalletAfterExceedingThresholdViewViewModel: PromptBackupWalletViewModel {
    let walletAddress: AlphaWallet.Address
    let dollarValueInUsd: Double

    var backgroundColor: UIColor {
        return .init(red: 183, green: 80, blue: 70)
    }

    var title: String {
        return R.string.localizable.backupPromptAfterHittingThresholdTitle(preferredLanguages: Languages.preferred())
    }

    var description: String {
        let prettyAmount = NumberFormatter.currency.string(from: dollarValueInUsd) ?? "-"
        return R.string.localizable.backupPromptAfterHittingThresholdDescription(prettyAmount)
    }

    var backupButtonBackgroundColor: UIColor {
        return UIColor(red: 119, green: 56, blue: 50)
    }
}
