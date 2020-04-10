//
//  SettingConnector.swift
//  AlphaWallet
//
//  Created by Nimit Parekh on 06/04/20.
//

import UIKit

class SettingConnector {
    static func getWalletSettings() -> [SettingModel] {
        let setting = [
            SettingModel(title: "Show My Wallet Address", subTitle: "", icon: R.image.walletAddress()),
            SettingModel(title: "Change / Add Wallet", subTitle: "tomek.eth | 0x4524...6363", icon: R.image.changeWallet()),
            SettingModel(title: R.string.localizable.settingsBackupWalletButtonTitle(), subTitle: "", icon: R.image.backupCircle()),
        ]
        return setting
    }
    static func getSystemSettings() -> [SettingModel] {
        let setting = [
            SettingModel(title: "Notifications", subTitle: "", icon: R.image.notificationsCircle()),
            SettingModel(title: "Passcode / Touch ID", subTitle: "", icon: R.image.biometrics()),
            SettingModel(title: "Select Active Networks", subTitle: "", icon: R.image.networksCircle()),
            SettingModel(title: R.string.localizable.advanced(), subTitle: "", icon: R.image.developerMode()),
        ]
        return setting
    }
    static func getHelpSettings() -> [SettingModel] {
        let setting = [
            SettingModel(title: "Support", subTitle: "", icon: R.image.support())
        ]
        return setting
    }
    static func getSettingsFooter() -> [SettingFooterModel] {
        let setting = [
            SettingFooterModel(title: "App Version", subTitle: "2.20.0(23)"),
            SettingFooterModel(title: "TokenScript Standard", subTitle: "2019/10")
        ]
        return setting
    }
}
