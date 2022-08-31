//
//  ShowSeedPhraseIntroductionViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.03.2021.
//

import UIKit
import AlphaWalletFoundation

struct ShowSeedPhraseIntroductionViewModel {

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var title: String {
        return R.string.localizable.walletsShowSeedPhraseIntroductionButtonTitle()
    }

    var imageViewImage: UIImage {
        return R.image.showSeedPhraseIntroduction()!
    }

    var attributedSubtitle: NSAttributedString {
        let subtitle = R.string.localizable.walletsShowSeedPhraseIntroductionTitle()
        let attributeString = NSMutableAttributedString(string: subtitle)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = ScreenChecker.size(big: 18, medium: 14, small: 7)

        attributeString.addAttributes([
            .paragraphStyle: style,
            .font: Screen.Backup.subtitleFont,
            .foregroundColor: R.color.black()!,
            .kern: 0.0
        ], range: NSRange(location: 0, length: subtitle.count))

        return attributeString
    }

    var attributedDescription: NSAttributedString {
        let description = R.string.localizable.walletsShowSeedPhraseIntroductionSubtitle()
        let attributedString = NSMutableAttributedString(string: description)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = ScreenChecker.size(big: 18, medium: 14, small: 7)

        attributedString.addAttributes([
            .paragraphStyle: style,
            .font: Screen.Backup.descriptionFont,
            .foregroundColor: Colors.appText,
            .kern: 0.0
        ], range: NSRange(location: 0, length: description.count))

        attributedString.addAttribute(.font, value: Screen.Backup.descriptionBoldFont, range: NSRange(location: 17, length: 5))

        return attributedString
    }

}
