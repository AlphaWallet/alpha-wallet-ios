// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

enum AppLocale {
    case system
    case english
    case simplifiedChinese
    case spanish
    case korean
    case japanese
    case finnish

    var id: String? {
        //Other than .system, the returned values must match the locale bundle names — eg. zh-Hans.lproj — included in the app
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        case .spanish:
            return "es"
        case .korean:
            return "ko"
        case .japanese:
            return "ja"
        case .finnish:
            return "fi"
        }
    }

    var localeIdentifier: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en_US"
        case .simplifiedChinese:
            return "zh_Hans_CN"
        case .spanish:
            return "es_ES"
        case .korean:
            return "ko"
        case .japanese:
            return "ja_JP"
        case .finnish:
            return "fi_FI"
        }
    }

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

    init(id: String?) {
        self = {
            guard let id = id else { return .system }
            if id == AppLocale.system.id {
                return .system
            } else if id == AppLocale.english.id {
                return .english
            } else if id == AppLocale.simplifiedChinese.id {
                return .simplifiedChinese
            } else if id == AppLocale.spanish.id {
                return .spanish
            } else if id == AppLocale.korean.id {
                return .korean
            } else if id == AppLocale.japanese.id {
                return .japanese
            } else if id == AppLocale.finnish.id {
                return .finnish
            } else {
                return .system
            }
        }()
    }
}
