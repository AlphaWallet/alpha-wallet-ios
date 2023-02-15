// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

struct MyDappCellViewModel: Hashable {
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

    var nameFont: UIFont {
        return Fonts.semibold(size: 12)
    }

    var domainNameFont: UIFont {
        return Fonts.bold(size: 10)
    }

    var nameColor: UIColor? {
        return Configuration.Color.Semantic.myDappCellName
    }

    var domainNameColor: UIColor? {
        return Configuration.Color.Semantic.appTint
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
}
