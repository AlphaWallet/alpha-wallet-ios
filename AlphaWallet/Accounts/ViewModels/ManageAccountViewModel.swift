// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

enum ManageAccountSection: Int, CaseIterable {
    case account
    case options
    
    var viewHeight: CGFloat {
        switch self {
        case .account:
            return 0.0
        default:
            return 50.0
        }
    }
}

enum ManageAccountOption: Int, CaseIterable {
    case showSeedPhrase
    case loseWallet
    case copyAddress
}
 
class ManageAccountViewModel {
    
    let wallet: Wallet
    var balance: Balance?
    private let keystore: Keystore
    var options: [ManageAccountOption]
    private var isHdWallet: Bool = false
    
    init(wallet: Wallet, balance: Balance?, keystore: Keystore) {
        self.wallet = wallet
        self.balance = balance
        self.keystore = keystore
        
        switch wallet.type {
        case .real(let account):
            isHdWallet = keystore.isHdWallet(account: account)
            self.options = ManageAccountOption.allCases
        case .watch:
            self.options = [.loseWallet, .copyAddress]
        }
    }
    
    var navigationTitle: String {
        return "Manage Wallet"
    }
    
    func numberOfSections() -> Int {
        return ManageAccountSection.allCases.count
    }
    
    func numberOfRows(in section: Int) -> Int {
        guard let section = ManageAccountSection(rawValue: section) else { return 0 }
        
        switch section {
        case .account:
            return 1
        case .options:
            return options.count
        }
    }
    
    func optionViewModel(indexPath: IndexPath) -> AccountOptionViewModel {
        switch self.options[indexPath.row] {
        case .copyAddress:
            return AccountOptionViewModel(title: R.string.localizable.copyAddress(), description: nil)
        case .showSeedPhrase:
            let title: String = isHdWallet ? R.string.localizable.walletsBackupHdWalletAlertSheetTitle() : R.string.localizable.walletsBackupKeystoreWalletAlertSheetTitle()
            return AccountOptionViewModel(title: title, description: R.string.localizable.walletsBackupHdWalletAlertSheetDescription())
        case .loseWallet:
            return AccountOptionViewModel(title: R.string.localizable.walletsLoseWalletAlertSheetTitle(), description: R.string.localizable.walletsLoseWalletAlertSheetDescription())
        }
    }
}
