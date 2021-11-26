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

    var imageViewImage: UIImage {
        return R.image.hdIntroduction()!
    }
    
    var attributedSubtitle: NSAttributedString {
        let subtitle = R.string.localizable.walletsBackupHdWalletIntroductionTitle()
        let attributeString = NSMutableAttributedString(string: subtitle)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = 0

        attributeString.addAttributes([
            .paragraphStyle: style,
            .font: Screen.Backup.subtitleFont,
            .foregroundColor: Colors.headerThemeColor
        ], range: NSRange(location: 0, length: subtitle.count))
        
        return attributeString
    }
    
    var attributedDescription: NSAttributedString {
        let description = R.string.localizable.walletsShowSeedPhraseDesc()
        let attributeString = NSMutableAttributedString(string: description)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = 0
        
        attributeString.addAttributes([
            .paragraphStyle: style,
            .font: Screen.Backup.WalletDescValue,
            .foregroundColor: Colors.headerThemeColor
        ], range: NSRange(location: 0, length: description.count))
        
        return attributeString
    } 
}
