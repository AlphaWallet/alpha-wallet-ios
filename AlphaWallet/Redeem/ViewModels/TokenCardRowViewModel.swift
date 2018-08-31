// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct TokenCardRowViewModel {
    var tokenHolder: TokenHolder?

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

    var tokenCountFont: UIFont {
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

    var tokenCount: String {
        guard let tokenHolder = tokenHolder else { return "" }
        return "x\(tokenHolder.tokens.count)"
    }

    var city: String {
        guard let tokenHolder = tokenHolder else { return "" }
        let value = tokenHolder.values["locality"] ?? "N/A"
        return ", \(value)"
    }

    var category: String {
        guard let tokenHolder = tokenHolder else { return "" }
        return tokenHolder.values["category"] as? String ?? "N/A"
    }

    var teams: String {
        guard let tokenHolder = tokenHolder else { return "" }
        let countryA = tokenHolder.values["countryA"] as? String ?? ""
        let countryB = tokenHolder.values["countryB"] as? String ?? ""
        return R.string.localizable.aWalletTokenMatchVs(countryA, countryB)
    }

    var match: String {
        guard let tokenHolder = tokenHolder else { return "" }
        let value = tokenHolder.values["match"] as? Int ?? 0
        return "M\(value)"
    }

    var venue: String {
        guard let tokenHolder = tokenHolder else { return "" }
        return tokenHolder.values["venue"] as? String ?? "N/A"
    }

    var date: String {
        guard let tokenHolder = tokenHolder else { return "" }
        let value = tokenHolder.values["time"] as? GeneralisedTime ?? GeneralisedTime()
        return value.formatAsShortDateString()
    }

    var time: String {
        guard let tokenHolder = tokenHolder else { return "" }
        let value = tokenHolder.values["time"] as? GeneralisedTime ?? GeneralisedTime()
        return value.format("h:mm a")
    }
}
