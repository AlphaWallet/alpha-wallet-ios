// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

struct CreateInitialViewModel {
    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var titleAttributedString: NSAttributedString {
        let font: UIFont = ScreenChecker().isNarrowScreen ? Fonts.regular(size: 20) : Fonts.regular(size: 30)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        return .init(string: R.string.localizable.gettingStartedSubtitle(), attributes: [
            .font: font,
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText,
            .paragraphStyle: paragraph
        ])
    }

    var imageViewImage: UIImage {
        return R.image.launchScreen()!
    }

    var createWalletButtonTitle: String {
        return R.string.localizable.gettingStartedNewWallet()
    }

    var alreadyHaveWalletButtonText: String {
        return R.string.localizable.gettingStartedAlreadyHaveWallet()
    }

    var watchButtonTitle: String {
        return R.string.localizable.gettingStartedAlertSheetOptionWatchTitle()
    }

    var importButtonTitle: String {
        return R.string.localizable.gettingStartedAlertSheetOptionImportTitle()
    }

}
