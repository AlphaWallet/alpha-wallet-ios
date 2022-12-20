// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

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
    var contentsBackgroundColor: UIColor { get }
    ///TODO get rid of this at some point
    var isMeetupContract: Bool { get }
    var tokenScriptHtml: String { get }
    var hasTokenScriptHtml: Bool { get }
    func subscribeStreetLocalityStateCountry(withBlock block: @escaping (String) -> Void)
    func subscribeBuilding(withBlock block: @escaping (String) -> Void)
}

extension TokenCardRowViewModelProtocol {
    var contentsBackgroundColor: UIColor {
        return Configuration.Color.Semantic.defaultViewBackground
    }

    var contentsCornerRadius: CGFloat {
        return DataEntry.Metric.CornerRadius.box
    }

    var titleColor: UIColor {
        return Configuration.Color.Semantic.defaultForegroundText
    }

    var countColor: UIColor {
        return Configuration.Color.Semantic.appreciation
    }

    var subtitleColor: UIColor {
        return UIColor(red: 112, green: 112, blue: 112)
    }

    var iconsColor: UIColor {
        return Configuration.Color.Semantic.symbol
    }

    var tokenCountFont: UIFont {
        return Fonts.bold(size: 21)
    }

    var titleFont: UIFont {
        return Fonts.regular(size: 21)
    }

    var venueFont: UIFont {
        return Fonts.regular(size: 16)
    }

    var stateBackgroundColor: UIColor {
        return UIColor(red: 151, green: 151, blue: 151)
    }

    var stateColor: UIColor {
        return .white
    }

    var subtitleFont: UIFont {
        return Fonts.semibold(size: ScreenChecker().isNarrowScreen ? 12 : 15)
    }

    var detailsFont: UIFont {
        return Fonts.regular(size: 16)
    }

}
