// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

struct ElevateWalletSecurityViewModel {
    let isHdWallet: Bool

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var title: String {
        if isHdWallet {
            return R.string.localizable.keystoreLockWalletSeedButton()
        } else {
            return R.string.localizable.keystoreLockWalletPrivateKeyButton()
        }
    }

    var subtitle: String {
        if isHdWallet {
            return R.string.localizable.keystoreLockWalletSeedTitle()
        } else {
            return R.string.localizable.keystoreLockWalletPrivateKeyTitle()
        }
    }

    var subtitleColor: UIColor {
        return Colors.appText
    }

    var subtitleFont: UIFont {
        return Fonts.regular(size: 22)!
    }

    var imageViewImage: UIImage {
        return R.image.biometricLock()!
    }

    var description: String {
        if isHdWallet {
            return R.string.localizable.keystoreLockWalletSeedDescription()
        } else {
            return R.string.localizable.keystoreLockWalletPrivateKeyDescription()
        }
    }

    var descriptionColor: UIColor {
        return Colors.darkGray
    }

    var descriptionFont: UIFont {
        return Fonts.regular(size: 20)!
    }

    var cancelLockingButtonFont: UIFont {
        return Fonts.regular(size: 20)!
    }

    var cancelLockingButtonTitleColor: UIColor {
        return Colors.appRed
    }
}
