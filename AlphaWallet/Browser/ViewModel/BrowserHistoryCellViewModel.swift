// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct BrowserHistoryCellViewModel {
    let history: History

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var imageUrl: URL? {
        return Favicon.get(for: URL(string: history.url))
    }

    var fallbackImage: UIImage? {
        return R.image.iconsTokensPlaceholder()
    }

    var name: String {
        return history.title
    }

    var url: String {
        return history.url
    }

    var nameFont: UIFont {
        return Fonts.semibold(size: 12)
    }

    var urlFont: UIFont {
        return Fonts.semibold(size: 10)
    }

    var nameColor: UIColor? {
        return UIColor(red: 77, green: 77, blue: 77)
    }

    var urlColor: UIColor? {
        return Colors.appTint
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
