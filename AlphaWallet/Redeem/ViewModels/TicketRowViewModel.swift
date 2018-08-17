// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct TicketRowViewModel {
    var ticketHolder: TokenHolder?

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
        let value = ticketHolder.values["locality"] ?? "N/A"
        return ", \(value)"
    }

    var category: String {
        guard let ticketHolder = ticketHolder else { return "" }
        return ticketHolder.values["category"] as? String ?? "N/A"
    }

    var teams: String {
        guard let ticketHolder = ticketHolder else { return "" }
        let countryA = ticketHolder.values["countryA"] as? String ?? ""
        let countryB = ticketHolder.values["countryB"] as? String ?? ""
        return R.string.localizable.aWalletTicketTokenMatchVs(countryA, countryB)
    }

    var match: String {
        guard let ticketHolder = ticketHolder else { return "" }
        let value = ticketHolder.values["match"] as? Int ?? 0
        return "M\(value)"
    }

    var venue: String {
        guard let ticketHolder = ticketHolder else { return "" }
        return ticketHolder.values["venue"] as? String ?? "N/A"
    }

    var date: String {
        guard let ticketHolder = ticketHolder else { return "" }
        let value = ticketHolder.values["time"] as? GeneralisedTime ?? GeneralisedTime()
        return value.formatAsShortDateString()
    }

    var time: String {
        guard let ticketHolder = ticketHolder else { return "" }
        let value = ticketHolder.values["time"] as? GeneralisedTime ?? GeneralisedTime()
        return value.format("h:mm a")
    }
}
