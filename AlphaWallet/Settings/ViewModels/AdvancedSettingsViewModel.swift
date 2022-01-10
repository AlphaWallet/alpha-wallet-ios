//
//  AdvancedSettingsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.06.2020.
//

import Foundation
import UIKit

struct AdvancedSettingsViewModel {
    var rows: [AdvancedSettingsRow] = {
        let privateNerworkRow: [AdvancedSettingsRow] = Features.isUsingPrivateNetwork ? [.usePrivateNetwork] : []
        if Features.isLanguageSwitcherDisabled {
            return [.console, .clearBrowserCache, .tokenScript, .pingInfura] + privateNerworkRow
        } else {
            return [.console, .clearBrowserCache, .tokenScript, .changeLanguage, .pingInfura] + privateNerworkRow
        }
    }()

    func numberOfRows() -> Int {
        return rows.count
    }
}

enum AdvancedSettingsRow: CaseIterable {
    case console
    case clearBrowserCache
    case tokenScript
    case changeLanguage
    case changeCurrency
    case analytics
    case usePrivateNetwork
    case pingInfura
    case exportJSONKeystore

    var title: String {
        switch self {
        case .console:
            return R.string.localizable.aConsoleTitle(preferredLanguages: Languages.preferred())
        case .clearBrowserCache:
            return R.string.localizable.aSettingsContentsClearDappBrowserCache(preferredLanguages: Languages.preferred())
        case .tokenScript:
            return R.string.localizable.aHelpAssetDefinitionOverridesTitle(preferredLanguages: Languages.preferred())
        case .changeLanguage:
            return R.string.localizable.settingsLanguageButtonTitle(preferredLanguages: Languages.preferred())
        case .changeCurrency:
            return R.string.localizable.settingsChangeCurrencyTitle(preferredLanguages: Languages.preferred())
        case .analytics:
            return R.string.localizable.settingsAnalitycsTitle(preferredLanguages: Languages.preferred())
        case .usePrivateNetwork:
            return R.string.localizable.settingsChooseSendPrivateTransactionsProviderButtonTitle(preferredLanguages: Languages.preferred())
        case .pingInfura:
            return R.string.localizable.settingsPingInfuraTitle(preferredLanguages: Languages.preferred())
        case .exportJSONKeystore:
            return R.string.localizable.settingsAdvancedExportJSONKeystoreTitle(preferredLanguages: Languages.preferred())
        }
    }

    var icon: UIImage {
        switch self {
        case .console:
            return R.image.settings_console()!
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
        case .pingInfura:
            //TODO need a more appropriate icon, maybe represent diagnostic or (to a lesser degree Infura)
            return R.image.settings_analytics()!
        case .exportJSONKeystore:
            return R.image.iconsSettingsJson()!
        }
    }
}
