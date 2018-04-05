// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct TicketRowViewModel {
    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var titleColor: UIColor {
        return Colors.appText
    }

    var countColor: UIColor {
        return Colors.appHighlightGreen
    }

    var subtitleColor: UIColor {
        return UIColor(red: 112, green: 112, blue: 112)
    }

    var iconsColor: UIColor {
        return Colors.appBackground
    }

    var ticketCountFont: UIFont {
        return Fonts.bold(size: 21)!
    }

    var titleFont: UIFont {
        return Fonts.light(size: 21)!
    }

    var venueFont: UIFont {
        return Fonts.light(size: 16)!
    }

    var stateBackgroundColor: UIColor {
        return UIColor(red: 151, green: 151, blue: 151)
    }

    var stateColor: UIColor {
        return .white
    }

    var subtitleFont: UIFont {
        if ScreenChecker().isNarrowScreen() {
            return Fonts.semibold(size: 12)!
        } else {
            return Fonts.semibold(size: 15)!
        }
    }
}
