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
            return R.string.localizable.keystore()
        case .privateKey:
            return R.string.localizable.privateKey()
        case .mnemonic:
            return R.string.localizable.mnemonic()
        case .watch:
            return R.string.localizable.watch()
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
