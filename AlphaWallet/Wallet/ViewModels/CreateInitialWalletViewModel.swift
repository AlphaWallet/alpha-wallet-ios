// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

struct CreateInitialViewModel {
    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var subtitle: String {
        return R.string.localizable.gettingStartedSubtitle()
    }

    var subtitleColor: UIColor {
        return Colors.appText
    }

    var subtitleFont: UIFont {
        if ScreenChecker().isNarrowScreen {
            return Fonts.regular(size: 16)
        } else {
            return Fonts.regular(size: 24)
        }
    }

    var imageViewImage: UIImage {
        return R.image.loginLogo()!
    }

    var createButtonTitle: String {
        return R.string.localizable.gettingStartedNewWallet()
    }

    var watchButtonTitle: String {
        return R.string.localizable.watch()
    }

    var importButtonTitle: String {
        return R.string.localizable.importWalletImportButtonTitle()
    }

    var alreadyHaveWalletText: String {
        return R.string.localizable.gettingStartedAlreadyHaveWallet()
    }

    var alreadyHaveWalletTextColor: UIColor {
        return Colors.appText
    }

    var alreadyHaveWalletTextFont: UIFont {
        return Fonts.regular(size: 18)
    }

    var separatorColor: UIColor {
        return .init(red: 235, green: 235, blue: 235)
    }
}
