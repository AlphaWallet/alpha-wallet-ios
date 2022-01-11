// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

struct PromptBackupWalletAfterIntervalViewViewModel: PromptBackupWalletViewModel {
    let walletAddress: AlphaWallet.Address

    var backgroundColor: UIColor {
        return .init(red: 97, green: 103, blue: 123)
    }

    var title: String {
        return R.string.localizable.backupPromptAfterIntervalTitle(preferredLanguages: Languages.preferred())
    }

    var description: String {
        return R.string.localizable.backupPromptAfterIntervalDescription(preferredLanguages: Languages.preferred())
    }

    var backupButtonBackgroundColor: UIColor {
        return UIColor(red: 65, green: 71, blue: 89)
    }
}
