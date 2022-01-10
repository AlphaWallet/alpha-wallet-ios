// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

struct CreateInitialViewModel {
    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var subtitle: String {
        return R.string.localizable.gettingStartedSubtitle(preferredLanguages: Languages.preferred())
    }

    var subtitleColor: UIColor {
        return Colors.appText
    }

    var subtitleFont: UIFont {
        if ScreenChecker().isNarrowScreen {
            return Fonts.regular(size: 20)
        } else {
            return Fonts.regular(size: 30)
        }
    }

    var imageViewImage: UIImage {
        return R.image.launch_icon()!
    }

    var createButtonTitle: String {
        return R.string.localizable.gettingStartedNewWallet(preferredLanguages: Languages.preferred())
    }

    var watchButtonTitle: String {
        return R.string.localizable.watch(preferredLanguages: Languages.preferred())
    }

    var importButtonTitle: String {
        return R.string.localizable.importWalletImportButtonTitle(preferredLanguages: Languages.preferred())
    }

    var alreadyHaveWalletText: String {
        return R.string.localizable.gettingStartedAlreadyHaveWallet(preferredLanguages: Languages.preferred())
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
