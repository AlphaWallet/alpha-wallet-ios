// Copyright © 2019 Stormbird PTE. LTD.

import AlphaWalletFoundation
import Foundation
import UIKit

struct PromptBackupWalletAfterIntervalViewViewModel: PromptBackupWalletViewModel {
    let walletAddress: AlphaWallet.Address

    var backgroundColor: UIColor {
        return Configuration.Color.Semantic.promptBackupWalletAfterIntervalViewBackground
    }

    var title: String {
        return R.string.localizable.backupPromptAfterIntervalTitle()
    }

    var description: String {
        return R.string.localizable.backupPromptAfterIntervalDescription()
    }

    var backupButtonBackgroundColor: UIColor {
        return Configuration.Color.Semantic.promptBackupWalletAfterIntervalViewBackupButtonBackground
    }
}
