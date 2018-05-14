// Copyright SIX DAY LLC. All rights reserved.

import UIKit

struct ImportWalletViewModel {
    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var title: String {
        return R.string.localizable.importNavigationTitle()
    }

    var buttonTitleColor: UIColor {
        return Colors.appWhite
    }

    var buttonBackgroundColor: UIColor {
        return Colors.appHighlightGreen
    }

    var buttonFont: UIFont {
        return Fonts.regular(size: 20)!
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

}
