// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct LocaleViewModel {
    private let locale: AppLocale
    private let isSelected: Bool

    init(locale: AppLocale, selected: Bool) {
        self.locale = locale
        self.isSelected = selected
    }

    var accessoryType: UITableViewCell.AccessoryType {
        if isSelected {
            return LocaleViewCell.selectionAccessoryType.selected
        } else {
            return LocaleViewCell.selectionAccessoryType.unselected
        }
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var localeFont: UIFont {
        return Fonts.regular(size: 17)!
    }

    var localeName: String {
        return locale.displayName
    }
}
