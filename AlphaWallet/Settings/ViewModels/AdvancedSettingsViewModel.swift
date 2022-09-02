//
//  AdvancedSettingsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.06.2020.
//

import Foundation
import UIKit
import AlphaWalletFoundation

struct AdvancedSettingsViewModel {
    var rows: [AdvancedSettingsRow]

    init(wallet: Wallet) {
        let canExportToJSONKeystore = Features.default.isAvailable(.isExportJsonKeystoreEnabled) && wallet.isReal()
        self.rows = [
            .clearBrowserCache,
            .tokenScript,
            Features.default.isAvailable(.isUsingPrivateNetwork) ? .usePrivateNetwork : nil,
            Features.default.isAvailable(.isAnalyticsUIEnabled) ? .analytics : nil,
            Features.default.isAvailable(.isLanguageSwitcherDisabled) ? nil : .changeLanguage,
            canExportToJSONKeystore ? .exportJSONKeystore : nil,
            .tools,
            (Environment.isDebug || Environment.isTestFlight) ? .features : nil,
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
    case features
    
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
        case .features:
            return R.string.localizable.advancedSettingsFeaturesTitle()
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
        case .features:
            return R.image.ticket_bundle_checked()!
        }
    }
}

fileprivate extension Wallet {
    func isReal() -> Bool {
        return type == .real(address)
    }
}

extension SendPrivateTransactionsProvider {
    var title: String {
        switch self {
        case .ethermine:
            return R.string.localizable.sendPrivateTransactionsProviderEtheremine()
        case .eden:
            return R.string.localizable.sendPrivateTransactionsProviderEden()
        }
    }

    var icon: UIImage {
        switch self {
        case .ethermine:
            return R.image.iconsSettingsEthermine()!
        case .eden:
            return R.image.iconsSettingsEden()!
        }
    }
}
