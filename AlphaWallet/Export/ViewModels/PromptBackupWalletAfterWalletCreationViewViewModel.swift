// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

struct PromptBackupWalletAfterWalletCreationViewViewModel: PromptBackupWalletViewViewModel {
    let walletAddress: AlphaWallet.Address

    var backgroundColor: UIColor {
        return .init(red: 183, green: 80, blue: 70)
    }

    var title: String {
        return R.string.localizable.backupPromptTitle()
    }

    var description: String {
        return R.string.localizable.backupPromptDescriptionWithoutAmount()
    }

    var backupButtonBackgroundColor: UIColor {
        return UIColor(red: 119, green: 56, blue: 50)
    }
}
