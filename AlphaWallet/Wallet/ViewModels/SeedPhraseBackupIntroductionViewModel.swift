// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

struct SeedPhraseBackupIntroductionViewModel {
    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var title: String {
        return R.string.localizable.walletsBackupHdWalletIntroductionButtonTitle()
    }

    var subtitle: String {
        return R.string.localizable.walletsBackupHdWalletIntroductionTitle()
    }

    var subtitleColor: UIColor {
        return Colors.appText
    }

    var subtitleFont: UIFont {
        return Fonts.regular(size: 22)!
    }

    var imageViewImage: UIImage {
        return R.image.hdIntroduction()!
    }

    var description1: String {
        return R.string.localizable.walletsShowSeedPhraseSubtitle()
    }

    var description2: String {
        return R.string.localizable.walletsShowSeedPhraseDescription()
    }

    var descriptionColor: UIColor {
        return Colors.darkGray
    }

    var descriptionFont: UIFont {
        return Fonts.regular(size: 18)!
    }
}
