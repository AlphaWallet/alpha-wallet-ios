//
//  AdvancedSettingsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.06.2020.
//

import Foundation
import UIKit

struct AdvancedSettingsViewModel {
    var rows: [AdvancedSettingsRow]

    init(keystore: Keystore) {
        let canExportToJSONKeystore = Features.isExportJsonKeystoreEnabled && keystore.currentWallet.isReal()
        self.rows = [
            .clearBrowserCache,
            .tokenScript,
            Features.isUsingPrivateNetwork ? .usePrivateNetwork : nil,
            Features.isAnalyticsUIEnabled ? .analytics : nil,
            Features.isLanguageSwitcherDisabled ? nil : .changeLanguage,
            canExportToJSONKeystore ? .exportJSONKeystore : nil,
            .tools
        ].compactMap { $0 }
    }

    func numberOfRows() -> Int {
        return rows.count
    }
}

enum AdvancedSettingsRow: CaseIterable {
    case tools
    case clearBrowserCache
    case tokenScript
    case changeLanguage
    case changeCurrency
    case analytics
    case usePrivateNetwork
    case exportJSONKeystore
    
    var title: String {
        switch self {
        case .tools:
            return R.string.localizable.aSettingsTools()
        case .clearBrowserCache:
            return R.string.localizable.aSettingsContentsClearDappBrowserCache()
        case .tokenScript:
            return R.string.localizable.aHelpAssetDefinitionOverridesTitle()
        case .changeLanguage:
            return R.string.localizable.settingsLanguageButtonTitle()
        case .changeCurrency:
            return R.string.localizable.settingsChangeCurrencyTitle()
        case .analytics:
            return R.string.localizable.settingsAnalitycsTitle()
        case .usePrivateNetwork:
            return R.string.localizable.settingsChooseSendPrivateTransactionsProviderButtonTitle()
        case .exportJSONKeystore:
            return R.string.localizable.settingsAdvancedExportJSONKeystoreTitle()
        }
    }

    var icon: UIImage {
        switch self {
        case .tools:
            return R.image.developerMode()!
        case .clearBrowserCache:
            return R.image.settings_clear_dapp_cache()!
        case .tokenScript:
            return R.image.settings_tokenscript_overrides()!
        case .changeLanguage:
            return R.image.settings_language()!
        case .changeCurrency:
            return R.image.settings_currency()!
        case .analytics:
            return R.image.settings_analytics()!
        case .usePrivateNetwork:
            return R.image.iconsSettingsEthermine()!
        case .exportJSONKeystore:
            return R.image.iconsSettingsJson()!
        }
    }
}

fileprivate extension Wallet {
    func isReal() -> Bool {
        return type == .real(address)
    }
}
