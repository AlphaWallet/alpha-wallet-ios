// Copyright SIX DAY LLC. All rights reserved.

import UIKit

struct ImportWalletViewModel {
    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var title: String {
        return R.string.localizable.importNavigationTitle()
    }

    var mnemonicLabel: String {
        return R.string.localizable.mnemonic().uppercased()
    }

    var keystoreJSONLabel: String {
        return R.string.localizable.keystoreJSON().uppercased()
    }

    var passwordLabel: String {
        return R.string.localizable.password().uppercased()
    }

    var privateKeyLabel: String {
        return R.string.localizable.privateKey().uppercased()
    }

    var watchAddressLabel: String {
        return R.string.localizable.ethereumAddress().uppercased()
    }

    var importKeystoreJsonButtonFont: UIFont {
        return Fonts.regular(size: 20)!
    }

    var importSeedDescriptionFont: UIFont {
        return Fonts.light(size: 16)!
    }

    var importSeedDescriptionColor: UIColor {
        return .init(red: 116, green: 116, blue: 116)
    }
}
