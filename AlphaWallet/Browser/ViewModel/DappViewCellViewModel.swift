// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

struct DappViewCellViewModel: Hashable {
    let bookmark: BookmarkObject

    var imageUrl: URL? {
        Favicon.get(for: bookmark.url)
    }

    var title: String {
        bookmark.title
    }

    var domainName: String {
        bookmark.url?.host ?? ""
    }

    init(bookmark: BookmarkObject) {
        self.bookmark = bookmark
    }

    var fallbackImage: UIImage? {
        return R.image.iconsTokensPlaceholder()
    }

    var backgroundColor: UIColor {
        return Configuration.Color.Semantic.defaultViewBackground
    }

    var imageViewShadowColor: UIColor {
        return Configuration.Color.Semantic.shadow
    }

    var imageViewShadowOffset: CGSize {
        return DataEntry.Metric.DappsHome.Icon.shadowOffset
    }

    var imageViewShadowOpacity: Float {
        return DataEntry.Metric.DappsHome.Icon.shadowOpacity
    }

    var imageViewShadowRadius: CGFloat {
        return DataEntry.Metric.DappsHome.Icon.shadowRadius
    }

    var titleColor: UIColor {
        return Configuration.Color.Semantic.defaultTitleText
    }

    var titleFont: UIFont {
        return Fonts.regular(size: 12)
    }

    var domainNameColor: UIColor {
        return Configuration.Color.Semantic.defaultViewBackground
    }

    var domainNameFont: UIFont {
        return Fonts.bold(size: 10)
    }
}
