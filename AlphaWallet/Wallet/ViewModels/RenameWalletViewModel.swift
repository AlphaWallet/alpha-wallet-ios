//
//  RenameWalletViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 31.03.2021.
//

import UIKit

struct RenameWalletViewModel {
    let account: AlphaWallet.Address

    var title: String {
        return R.string.localizable.settingsWalletRename(preferredLanguages: Languages.preferred())
    }

    var saveWalletNameTitle: String {
        return R.string.localizable.walletRenameSave(preferredLanguages: Languages.preferred())
    }

    var walletNameTitle: String {
        return R.string.localizable.walletRenameEnterNameTitle(preferredLanguages: Languages.preferred())
    }

    init(account: AlphaWallet.Address) {
        self.account = account
    }
}
