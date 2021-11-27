// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol PromptBackupWalletViewModel {
    var backgroundColor: UIColor { get }
    var cornerRadius: CGFloat { get }
    var titleFont: UIFont { get }
    var titleColor: UIColor { get }
    var title: String { get }
    var descriptionFont: UIFont { get }
    var descriptionColor: UIColor { get }
    var description: String { get }
    var backupButtonBackgroundColor: UIColor { get }
    var backupButtonTitleColor: UIColor { get }
    var backupButtonTitle: String { get }
    var backupButtonTitleFont: UIFont { get }
    var backupButtonImage: UIImage { get }
    var backupButtonContentEdgeInsets: UIEdgeInsets { get }
    var moreButtonImage: UIImage { get }
    var moreButtonColor: UIColor { get }
    var walletAddress: AlphaWallet.Address { get }
}

extension PromptBackupWalletViewModel {
    var cornerRadius: CGFloat {
        return Metrics.CornerRadius.backUp
    }

    var titleFont: UIFont {
        return Fonts.bold(size: 18)
    }

    var titleColor: UIColor {
        return Colors.appWhite
    }

    var descriptionFont: UIFont {
        return Fonts.bold(size: 10)
    }

    var descriptionColor: UIColor {
        return Colors.appWhite
    }

    var backupButtonTitleColor: UIColor {
        return Colors.appWhite
    }

    var backupButtonTitleFont: UIFont {
        return Fonts.semibold(size: 10)
    }

    var backupButtonImage: UIImage {
        return R.image.toolbarForward()!
    }

    var backupButtonContentEdgeInsets: UIEdgeInsets {
        return .init(top: 7, left: 21, bottom: 7, right: 21)
    }

    var moreButtonImage: UIImage {
        return R.image.toolbarMenu()!
    }

    var moreButtonColor: UIColor {
        return Colors.appWhite
    }

    var backupButtonTitle: String {
        return "\(R.string.localizable.backupPromptBackupButtonTitle().uppercased()) "
    }
}
