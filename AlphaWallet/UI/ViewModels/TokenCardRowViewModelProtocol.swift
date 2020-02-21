// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol TokenCardRowViewModelProtocol {
    var tokenCount: String { get }
    var city: String { get }
    var category: String { get }
    var teams: String { get }
    var match: String { get }
    var venue: String { get }
    var date: String { get }
    var time: String { get }
    var numero: String { get }
    var onlyShowTitle: Bool { get }
    ///TODO get rid of this at some point
    var isMeetupContract: Bool { get }
    var tokenScriptHtml: (html: String, hash: Int) { get }
    var hasTokenScriptHtml: Bool { get }
    func subscribeStreetLocalityStateCountry(withBlock block: @escaping (String) -> Void)
    func subscribeBuilding(withBlock block: @escaping (String) -> Void)
}

extension TokenCardRowViewModelProtocol {
    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var contentsCornerRadius: CGFloat {
        return Metrics.CornerRadius.box
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
        return Colors.navigationTitleColor
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
        if ScreenChecker().isNarrowScreen {
            return Fonts.semibold(size: 12)!
        } else {
            return Fonts.semibold(size: 15)!
        }
    }

    var detailsFont: UIFont {
        return Fonts.light(size: 16)!
    }

    var buttonTitleColor: UIColor {
        return Colors.appWhite
    }

    var disabledButtonTitleColor: UIColor {
        return Colors.darkGray
    }

    var buttonBackgroundColor: UIColor {
        return Colors.appHighlightGreen
    }

    var buttonFont: UIFont {
        return Fonts.regular(size: 20)!
    }
}
