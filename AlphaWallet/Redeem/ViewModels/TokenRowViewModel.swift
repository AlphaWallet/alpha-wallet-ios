// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct TokenRowViewModel {
    var TokenHolder: TokenHolder?

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

    var TokenCountFont: UIFont {
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

    var TokenCount: String {
        guard let TokenHolder = TokenHolder else { return "" }
        return "x\(TokenHolder.Tokens.count)"
    }

    var city: String {
        guard let TokenHolder = TokenHolder else { return "" }
        let value = TokenHolder.values["locality"] ?? "N/A"
        return ", \(value)"
    }

    var category: String {
        guard let TokenHolder = TokenHolder else { return "" }
        return TokenHolder.values["category"] as? String ?? "N/A"
    }

    var teams: String {
        guard let TokenHolder = TokenHolder else { return "" }
        let countryA = TokenHolder.values["countryA"] as? String ?? ""
        let countryB = TokenHolder.values["countryB"] as? String ?? ""
        return R.string.localizable.aWalletTokenTokenMatchVs(countryA, countryB)
    }

    var match: String {
        guard let TokenHolder = TokenHolder else { return "" }
        let value = TokenHolder.values["match"] as? Int ?? 0
        return "M\(value)"
    }

    var venue: String {
        guard let TokenHolder = TokenHolder else { return "" }
        return TokenHolder.values["venue"] as? String ?? "N/A"
    }

    var date: String {
        guard let TokenHolder = TokenHolder else { return "" }
        let value = TokenHolder.values["time"] as? GeneralisedTime ?? GeneralisedTime()
        return value.formatAsShortDateString()
    }

    var time: String {
        guard let TokenHolder = TokenHolder else { return "" }
        let value = TokenHolder.values["time"] as? GeneralisedTime ?? GeneralisedTime()
        return value.format("h:mm a")
    }
}
