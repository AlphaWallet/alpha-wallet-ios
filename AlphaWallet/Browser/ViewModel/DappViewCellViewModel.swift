// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class DappViewCellViewModel {
    let dapp: Bookmark
    var imageUrl: URL?
    var title: String {
        return dapp.title
    }

    var fallbackImage: UIImage? {
        return R.image.iconsTokensPlaceholder()
    }

    var domainName: String {
        return URL(string: dapp.url)?.host ?? ""
    }

    init(dapp: Bookmark) {
        self.dapp = dapp
        self.imageUrl = Favicon.get(for: URL(string: dapp.url))
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
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

    var titleColor: UIColor {
        return UIColor(red: 77, green: 77, blue: 77)
    }

    var titleFont: UIFont {
        return Fonts.regular(size: 12)
    }

    var domainNameColor: UIColor {
        return Colors.appBackground
    }

    var domainNameFont: UIFont {
        return Fonts.bold(size: 10)
    }
}
