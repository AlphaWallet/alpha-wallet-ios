// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

enum Language {
    case system
    case english
    case simplifiedChinese
    case spanish

    var id: String? {
        //Other than .system, the returned values must match the language bundle names — eg. zh-Hans.lproj — included in the app
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        case .spanish:
            return "es"
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
        }
    }

    init(id: String?) {
        self = {
            guard let id = id else { return .system }
            if id == Language.system.id {
                return .system
            } else if id == Language.english.id {
                return .english
            } else if id == Language.simplifiedChinese.id {
                return .simplifiedChinese
            } else if id == Language.spanish.id {
                return .spanish
            } else {
                return .system
            }
        }()
    }
}
