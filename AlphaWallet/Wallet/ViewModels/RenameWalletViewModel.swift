//
//  RenameWalletViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 31.03.2021.
//

import Foundation

struct RenameWalletViewModel {
    let account: AlphaWallet.Address

    var title: String {
        return R.string.localizable.settingsWalletRename()
    }

    var saveWalletNameTitle: String {
        return R.string.localizable.walletRenameSave()
    }

    var walletNameTitle: String {
        return R.string.localizable.walletRenameEnterNameTitle()
    }

    init(account: AlphaWallet.Address) {
        self.account = account
    }
}
