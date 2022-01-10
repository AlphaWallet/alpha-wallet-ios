// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum ImportSelectionType {
    case keystore
    case privateKey
    case mnemonic
    case watch

    var title: String {
        switch self {
        case .keystore:
            if ScreenChecker().isNarrowScreen {
                return R.string.localizable.keystoreShorter(preferredLanguages: Languages.preferred())
            } else {
                return R.string.localizable.keystore(preferredLanguages: Languages.preferred())
            }
        case .privateKey:
            return R.string.localizable.privateKey(preferredLanguages: Languages.preferred())
        case .mnemonic:
            return R.string.localizable.mnemonic(preferredLanguages: Languages.preferred())
        case .watch:
            return R.string.localizable.watch(preferredLanguages: Languages.preferred())
        }
    }

    init(title: String?) {
        switch title {
        case ImportSelectionType.privateKey.title?:
            self = .privateKey
        case ImportSelectionType.watch.title?:
            self = .watch
        case ImportSelectionType.mnemonic.title?:
            self = .mnemonic
        default:
            self = .keystore
        }
    }
}
