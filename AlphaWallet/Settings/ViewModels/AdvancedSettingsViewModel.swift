//
//  AdvancedSettingsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.06.2020.
//

import Foundation
import UIKit

struct AdvancedSettingsViewModel {
    
    var rows: [AdvancedSettingsRow] = [.console, .clearBrowserCache, .tokenScript, .changeLanguage]
    
    func numberOfRows() -> Int {
        return rows.count
    }
    
    func cellViewModel(indexPath: IndexPath) -> SettingTableViewCellViewModel {
        let row = rows[indexPath.row]
        return .init(titleText: row.title, subTitleText: nil, icon: row.icon)
    }
}

enum AdvancedSettingsRow: CaseIterable {
    case console
    case clearBrowserCache
    case tokenScript
    case changeLanguage
    case changeCurrency
    case analytics

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
        }
    }
} 
