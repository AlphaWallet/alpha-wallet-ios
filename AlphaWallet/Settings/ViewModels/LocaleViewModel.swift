// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

struct LocaleViewModel {
    private let locale: AppLocale
    private let isSelected: Bool

    init(locale: AppLocale, selected: Bool) {
        self.locale = locale
        self.isSelected = selected
    }

    var accessoryType: UITableViewCell.AccessoryType {
        if isSelected {
            return LocaleViewCell.selectionAccessoryType.selected
        } else {
            return LocaleViewCell.selectionAccessoryType.unselected
        }
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var localeFont: UIFont {
        return Fonts.regular(size: 17)
    }

    var localeName: String {
        return locale.displayName
    }
}

extension AppLocale {
    var displayName: String {
        //Only .system should be localized. The rest should each be in their own language
        switch self {
        case .system:
            return R.string.localizable.settingsLanguageUseSystemTitle()
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        case .spanish:
            return "Español"
        case .korean:
            return "한국어"
        case .japanese:
            return "日本語"
        case .finnish:
            return "Suomi"
        }
    }
}
