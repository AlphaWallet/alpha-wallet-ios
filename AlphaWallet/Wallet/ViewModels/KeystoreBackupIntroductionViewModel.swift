// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

struct KeystoreBackupIntroductionViewModel {
    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var title: String {
        //The longer version is too long when another view controller is pushed onto it
        let _ = R.string.localizable.walletsBackupKeystoreWalletAlertSheetTitle(preferredLanguages: Languages.preferred())
        return R.string.localizable.walletsBackupKeystoreWalletAlertSheetTitleShorter(preferredLanguages: Languages.preferred())
    }

    var subtitle: String {
        return R.string.localizable.walletsBackupKeystoreWalletIntroductionTitle(preferredLanguages: Languages.preferred())
    }

    var subtitleColor: UIColor {
        return Screen.Backup.subtitleColor
    }

    var subtitleFont: UIFont {
        return Screen.Backup.subtitleFont
    }

    var imageViewImage: UIImage {
        return R.image.keystoreIntroduction()!
    }

    var description: String {
        return R.string.localizable.walletsBackupKeystoreWalletIntroductionDescription(preferredLanguages: Languages.preferred())
    }

    var descriptionColor: UIColor {
        return Screen.Backup.descriptionColor
    }

    var descriptionFont: UIFont {
        return Screen.Backup.descriptionFont
    }
}
