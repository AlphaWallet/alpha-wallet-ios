// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt

struct PromptBackupWalletAfterReceivingNativeCryptoCurrencyViewViewModel: PromptBackupWalletViewViewModel {
    let walletAddress: AlphaWallet.Address
    let nativeCryptoCurrency: BigInt

    var backgroundColor: UIColor {
        return .init(red: 97, green: 103, blue: 123)
    }

    var title: String {
        let formatter = EtherNumberFormatter.short
        let amount = formatter.string(from: nativeCryptoCurrency, decimals: 18)
        return R.string.localizable.backupPromptAfterReceivingEtherTitle(amount)
    }

    var description: String {
        return R.string.localizable.backupPromptDescriptionWithoutAmount()
    }

    var backupButtonBackgroundColor: UIColor {
        return UIColor(red: 65, green: 71, blue: 89)
    }
}
