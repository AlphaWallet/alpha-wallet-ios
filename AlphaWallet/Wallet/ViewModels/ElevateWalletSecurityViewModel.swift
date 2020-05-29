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

    var attributedSubtitle: NSAttributedString {
        let attributeString = NSMutableAttributedString(string: subtitle)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = ScreenChecker().isNarrowScreen ? 7 : 23

        attributeString.addAttributes([
            .paragraphStyle: style,
            .font: Screen.Backup.subtitleFont,
            .foregroundColor: R.color.black()!
        ], range: NSRange(location: 0, length: subtitle.count))

        return attributeString
    }

    var attributedDescription: NSAttributedString {
        let attributeString = NSMutableAttributedString(string: description)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = ScreenChecker().isNarrowScreen ? 7 : 14

        attributeString.addAttributes([
            .paragraphStyle: style,
            .font: descriptionFont,
            .foregroundColor: Colors.appText
        ], range: NSRange(location: 0, length: description.count))

        return attributeString
    }

    private var descriptionFont: UIFont {
        if ScreenChecker().isNarrowScreen {
            return Fonts.regular(size: 16)!
        } else {
            return Fonts.regular(size: 20)!
        }
    }

    var cancelLockingButtonFont: UIFont {
        return Fonts.regular(size: 20)!
    }

    var cancelLockingButtonTitleColor: UIColor {
        return Colors.appRed
    }
}
