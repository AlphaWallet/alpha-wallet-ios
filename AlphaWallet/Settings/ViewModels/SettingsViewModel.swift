// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

struct SettingsViewModel {
    private let account: Wallet

    func addressReplacedWithENSOrWalletName(_ ensOrWalletName: String? = nil) -> String {
        if let ensOrWalletName = ensOrWalletName {
            return "\(ensOrWalletName) | \(account.address.truncateMiddle)"
        } else {
            return account.address.eip55String
        }
    }

    var passcodeTitle: String {
        switch BiometryAuthenticationType.current {
        case .faceID, .touchID:
            return R.string.localizable.settingsBiometricsEnabledLabelTitle(BiometryAuthenticationType.current.title)
        case .none:
            return R.string.localizable.settingsBiometricsDisabledLabelTitle()
        }
    }

    var localeTitle: String {
        return R.string.localizable.settingsLanguageButtonTitle()
    }

    let sections: [SettingsSection]

    init(account: Wallet) {
        self.account = account
        let walletRows: [SettingsWalletRow] = account.allowBackup ? SettingsWalletRow.allCases : [.showMyWallet, .changeWallet]
        sections = [
            .wallet(rows: walletRows),
            .system(rows: [.passcode, .selectActiveNetworks, .advanced]),
            .help,
            .version(value: Bundle.main.fullVersion),
            .tokenStandard(value: "\(TokenScript.supportedTokenScriptNamespaceVersion)")
        ]
    }

    func numberOfSections() -> Int {
        return sections.count
    }

    func numberOfSections(in section: Int) -> Int {
        switch sections[section] {
        case .wallet(let rows):
            return rows.count
        case .help:
            return 1
        case .system(let rows):
            return rows.count
        case .version, .tokenStandard:
            return 0
        }
    }
}

enum SettingsWalletRow: CaseIterable {
    case showMyWallet
    case changeWallet
    case backup

    var title: String {
        switch self {
        case .showMyWallet:
            return R.string.localizable.settingsShowMyWalletTitle()
        case .changeWallet:
            return R.string.localizable.settingsChangeWalletTitle()
        case .backup:
            return R.string.localizable.settingsBackupWalletButtonTitle()
        }
    }

    var icon: UIImage {
        switch self {
        case .showMyWallet:
            return R.image.walletAddress()!
        case .changeWallet:
            return R.image.changeWallet()!
        case .backup:
            return R.image.backupCircle()!
        }
    }
}

enum SettingsSystemRow: CaseIterable {
    case notifications
    case passcode
    case selectActiveNetworks
    case advanced

    var title: String {
        switch self {
        case .notifications:
            return R.string.localizable.settingsNotificationsTitle()
        case .passcode:
            return R.string.localizable.settingsPasscodeTitle()
        case .selectActiveNetworks:
            return R.string.localizable.settingsSelectActiveNetworksTitle()
        case .advanced:
            return R.string.localizable.advanced()
        }
    }

    var icon: UIImage {
        switch self {
        case .notifications:
            return R.image.notificationsCircle()!
        case .passcode:
            return R.image.biometrics()!
        case .selectActiveNetworks:
            return R.image.networksCircle()!
        case .advanced:
            return R.image.developerMode()!
        }
    }
}

enum SettingsSection {
    case wallet(rows: [SettingsWalletRow])
    case system(rows: [SettingsSystemRow])
    case help
    case version(value: String)
    case tokenStandard(value: String)

    var title: String {
        switch self {
        case .wallet:
            return R.string.localizable.settingsSectionWalletTitle().uppercased()
        case .system:
            return R.string.localizable.settingsSectionSystemTitle().uppercased()
        case .help:
            return R.string.localizable.settingsSectionHelpTitle().uppercased()
        case .version:
            return R.string.localizable.settingsVersionLabelTitle()
        case .tokenStandard:
            return R.string.localizable.settingsTokenScriptStandardTitle()
        }
    }

    var numberOfRows: Int {
        switch self {
        case .wallet(let rows):
            return rows.count
        case .help:
            return 1
        case .system(let rows):
            return rows.count
        case .version, .tokenStandard:
            return 0
        }
    }
}
