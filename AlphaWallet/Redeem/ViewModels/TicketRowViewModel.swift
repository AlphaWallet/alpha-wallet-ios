// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct TicketRowViewModel {
    var ticketHolder: TicketHolder? = nil

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

    var detailsFont: UIFont {
        return Fonts.light(size: 16)!
    }

    var ticketCount: String {
        guard let ticketHolder = ticketHolder else { return "" }
        return "x\(ticketHolder.tickets.count)"
    }

    var city: String {
        guard let ticketHolder = ticketHolder else { return "" }
        return ", \(ticketHolder.city)"
    }

    var category: String {
        guard let ticketHolder = ticketHolder else { return "" }
        return String(ticketHolder.category)
    }

    var teams: String {
        guard let ticketHolder = ticketHolder else { return "" }
        return R.string.localizable.aWalletTicketTokenMatchVs(ticketHolder.countryA, ticketHolder.countryB)
    }

    var match: String {
        guard let ticketHolder = ticketHolder else { return "" }
        return "M\(ticketHolder.match)"
    }

    var venue: String {
        guard let ticketHolder = ticketHolder else { return "" }
        return ticketHolder.venue
    }

    var date: String {
        guard let ticketHolder = ticketHolder else { return "" }
        return ticketHolder.date.formatAsShortDateString(overrideWithTimezoneIdentifier: ticketHolder.timeZoneIdentifier)
    }

    var time: String {
        guard let ticketHolder = ticketHolder else { return "" }
        return ticketHolder.date.format("h:mm a", overrideWithTimezoneIdentifier: ticketHolder.timeZoneIdentifier)
    }
}
