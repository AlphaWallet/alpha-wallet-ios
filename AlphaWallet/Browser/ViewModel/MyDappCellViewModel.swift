// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct MyDappCellViewModel {
    let dapp: Bookmark

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var imageUrl: URL? {
        return Favicon.get(for: URL(string: dapp.url))
    }

    var fallbackImage: UIImage? {
        return R.image.iconsTokensPlaceholder()
    }

    var name: String {
        return dapp.title
    }

    var domainName: String {
        return URL(string: dapp.url)?.host ?? ""
    }

    var nameFont: UIFont {
        return Fonts.semibold(size: 12)
    }

    var domainNameFont: UIFont {
        return Fonts.bold(size: 10)
    }

    var nameColor: UIColor? {
        return UIColor(red: 77, green: 77, blue: 77)
    }

    var domainNameColor: UIColor? {
        return Colors.appTint
    }

    var addRemoveButtonFont: UIFont {
        return Fonts.semibold(size: 12)
    }

    var addRemoveButtonContentEdgeInsets: UIEdgeInsets {
        return .init(top: 7, left: 14, bottom: 7, right: 14)
    }

    var addRemoveButtonBorderColor: UIColor {
        return Colors.appBackground
    }

    var addRemoveButtonBorderWidth: CGFloat {
        return 1
    }

    var addRemoveButtonBorderCornerRadius: CGFloat {
        return 9
    }

    var imageViewShadowColor: UIColor {
        return Metrics.DappsHome.Icon.shadowColor
    }

    var imageViewShadowOffset: CGSize {
        return Metrics.DappsHome.Icon.shadowOffset
    }

    var imageViewShadowOpacity: Float {
        return Metrics.DappsHome.Icon.shadowOpacity
    }

    var imageViewShadowRadius: CGFloat {
        return Metrics.DappsHome.Icon.shadowRadius
    }
}
