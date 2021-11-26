// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

struct PromptBackupWalletAfterWalletCreationViewViewModel: PromptBackupWalletViewModel {
    let walletAddress: AlphaWallet.Address

    var backgroundColor: UIColor {
        return UIColor(hex: "FE4443")
    }
 
    var title: String {
        return R.string.localizable.backupPromptTitle()
    }

    var description: String {
        return R.string.localizable.backupPromptDescriptionWithoutAmount()
    }

    var backupButtonBackgroundColor: UIColor {
        return UIColor.clear
    }
}
