// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

struct SettingsViewModel {
    private let account: Wallet

    let blockscanChatUnreadCount: Int?

    func addressReplacedWithENSOrWalletName(_ ensOrWalletName: String? = nil) -> String {
        if let ensOrWalletName = ensOrWalletName {
            return "\(ensOrWalletName) | \(account.address.truncateMiddle)"
        } else {
            return account.address.truncateMiddle
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

    init(account: Wallet, keystore: Keystore, blockscanChatUnreadCount: Int?) {
        self.account = account
        self.blockscanChatUnreadCount = blockscanChatUnreadCount
        sections = SettingsViewModel.functional.computeSections(account: account, keystore: keystore, blockscanChatUnreadCount: blockscanChatUnreadCount)
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

extension SettingsViewModel {
    enum functional {}
}

extension SettingsViewModel.functional {
    fileprivate static func computeSections(account: Wallet, keystore: Keystore, blockscanChatUnreadCount: Int?) -> [SettingsSection] {
        let walletRows: [SettingsWalletRow]
        if account.allowBackup {
            if keystore.isHdWallet(wallet: account) {
                walletRows = [.showMyWallet, .changeWallet, .backup, .showSeedPhrase, .nameWallet, .walletConnect, .blockscanChat(blockscanChatUnreadCount: blockscanChatUnreadCount)]
            } else {
                walletRows = [.showMyWallet, .changeWallet, .backup, .nameWallet, .walletConnect, .blockscanChat(blockscanChatUnreadCount: blockscanChatUnreadCount)]
            }
        } else {
            walletRows = [.showMyWallet, .changeWallet, .nameWallet, .walletConnect, .blockscanChat(blockscanChatUnreadCount: blockscanChatUnreadCount)]
        }
        return [
            .wallet(rows: walletRows),
            .system(rows: [.passcode, .selectActiveNetworks, .advanced]),
            .help,
            .version(value: Bundle.main.fullVersion),
            .tokenStandard(value: "\(TokenScript.supportedTokenScriptNamespaceVersion)")
        ]
    }
}

enum SettingsWalletRow {
    case showMyWallet
    case changeWallet
    case backup
    case showSeedPhrase
    case walletConnect
    case nameWallet
    case blockscanChat(blockscanChatUnreadCount: Int?)

    var title: String {
        switch self {
        case .showMyWallet:
            return R.string.localizable.settingsShowMyWalletTitle()
        case .changeWallet:
            return R.string.localizable.settingsChangeWalletTitle()
        case .backup:
            return R.string.localizable.settingsBackupWalletButtonTitle()
        case .showSeedPhrase:
            return R.string.localizable.settingsShowSeedPhraseButtonTitle()
        case .walletConnect:
            return R.string.localizable.settingsWalletConnectButtonTitle()
        case .nameWallet:
            return R.string.localizable.settingsWalletRename()
        case .blockscanChat(let blockscanChatUnreadCount):
            if let blockscanChatUnreadCount = blockscanChatUnreadCount, blockscanChatUnreadCount > 0 {
                return "\(R.string.localizable.settingsBlockscanChat()) (\(blockscanChatUnreadCount))"
            } else {
                return R.string.localizable.settingsBlockscanChat()
            }
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
        case .blockscanChat:
            return R.image.settingsBlockscanChat()!
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
