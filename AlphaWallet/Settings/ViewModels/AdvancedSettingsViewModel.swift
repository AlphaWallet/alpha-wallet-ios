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
        if Features.isLanguageSwitcherDisabled {
            return [.console, .clearBrowserCache, .tokenScript, .useTaiChiNetwork]
        } else {
            return [.console, .clearBrowserCache, .tokenScript, .changeLanguage, .useTaiChiNetwork]
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
    case useTaiChiNetwork

    var title: String {
        switch self {
        case .console:
            return R.string.localizable.aConsoleTitle()
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
        case .useTaiChiNetwork:
            return R.string.localizable.settingsUseTaichiNetworkButtonTitle()
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
        case .useTaiChiNetwork:
            return R.image.iconsSettingsTaiChi()!
        }
    }
}
