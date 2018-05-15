// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct LocaleViewModel {
    let locale: AppLocale
    let isSelected: Bool

    init(locale: AppLocale, selected: Bool) {
        self.locale = locale
        self.isSelected = selected
    }

    var selectionIcon: UIImage {
        if isSelected {
            return R.image.ticket_bundle_checked()!
        } else {
            return R.image.ticket_bundle_unchecked()!
        }
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var contentsBackgroundColor: UIColor {
        return backgroundColor
    }

    var contentsBorderColor: UIColor {
        return Colors.appHighlightGreen
    }

    var contentsBorderWidth: CGFloat {
        return 1
    }

    var localeFont: UIFont {
        return Fonts.light(size: 20)!
    }

    var localeName: String {
        return locale.displayName
    }
}
