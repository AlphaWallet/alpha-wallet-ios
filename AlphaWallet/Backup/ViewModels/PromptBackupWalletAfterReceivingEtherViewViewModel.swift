// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import AlphaWalletFoundation

struct PromptBackupWalletAfterReceivingNativeCryptoCurrencyViewViewModel: PromptBackupWalletViewModel {
    let walletAddress: AlphaWallet.Address
    let nativeCryptoCurrency: BigInt

    var backgroundColor: UIColor {
        return Configuration.Color.Semantic.promptBackupWalletAfterReceivingNativeCryptoCurrencyViewBackground
    }

    var title: String {
        let formatter = EtherNumberFormatter.short
        let amount = formatter.string(from: nativeCryptoCurrency)
        return R.string.localizable.backupPromptAfterReceivingEtherTitle(amount)
    }

    var description: String {
        return R.string.localizable.backupPromptDescriptionWithoutAmount()
    }

    var backupButtonBackgroundColor: UIColor {
        return Configuration.Color.Semantic.promptBackupWalletAfterReceivingNativeCryptoCurrencyViewBackupButtonBackground
    }
}
