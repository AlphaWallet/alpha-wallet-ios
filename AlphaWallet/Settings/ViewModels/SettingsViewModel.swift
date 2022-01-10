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
            return R.string.localizable.settingsBiometricsDisabledLabelTitle(preferredLanguages: Languages.preferred())
        }
    }

    var localeTitle: String {
        return R.string.localizable.settingsLanguageButtonTitle(preferredLanguages: Languages.preferred())
    }

    let sections: [SettingsSection]

    init(account: Wallet, keystore: Keystore) {
        self.account = account
        let walletRows: [SettingsWalletRow]

        if account.allowBackup {
            if keystore.isHdWallet(wallet: account) {
                walletRows = [.showMyWallet, .changeWallet, .backup, .showSeedPhrase, .nameWallet, .walletConnect]
            } else {
                walletRows = [.showMyWallet, .changeWallet, .backup, .nameWallet, .walletConnect]
            }
        } else {
            walletRows = [.showMyWallet, .changeWallet, .nameWallet, .walletConnect]
        }

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
    case showSeedPhrase
    case walletConnect
    case nameWallet

    var title: String {
        switch self {
        case .showMyWallet:
            return R.string.localizable.settingsShowMyWalletTitle(preferredLanguages: Languages.preferred())
        case .changeWallet:
            return R.string.localizable.settingsChangeWalletTitle(preferredLanguages: Languages.preferred())
        case .backup:
            return R.string.localizable.settingsBackupWalletButtonTitle(preferredLanguages: Languages.preferred())
        case .showSeedPhrase:
            return R.string.localizable.settingsShowSeedPhraseButtonTitle(preferredLanguages: Languages.preferred())
        case .walletConnect:
            return R.string.localizable.settingsWalletConnectButtonTitle(preferredLanguages: Languages.preferred())
        case .nameWallet:
            return R.string.localizable.settingsWalletRename(preferredLanguages: Languages.preferred())
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
        case .showSeedPhrase:
            return R.image.iconsSettingsSeed2()!
        case .walletConnect:
            return R.image.iconsSettingsWalletConnect()!
        case .nameWallet:
            return R.image.iconsSettingsDisplayedEns()!
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
            return R.string.localizable.settingsNotificationsTitle(preferredLanguages: Languages.preferred())
        case .passcode:
            return R.string.localizable.settingsPasscodeTitle(preferredLanguages: Languages.preferred())
        case .selectActiveNetworks:
            return R.string.localizable.settingsSelectActiveNetworksTitle(preferredLanguages: Languages.preferred())
        case .advanced:
            return R.string.localizable.advanced(preferredLanguages: Languages.preferred())
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
            return R.string.localizable.settingsSectionWalletTitle(preferredLanguages: Languages.preferred()).uppercased()
        case .system:
            return R.string.localizable.settingsSectionSystemTitle(preferredLanguages: Languages.preferred()).uppercased()
        case .help:
            return R.string.localizable.settingsSectionHelpTitle(preferredLanguages: Languages.preferred()).uppercased()
        case .version:
            return R.string.localizable.settingsVersionLabelTitle(preferredLanguages: Languages.preferred())
        case .tokenStandard:
            return R.string.localizable.settingsTokenScriptStandardTitle(preferredLanguages: Languages.preferred())
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
