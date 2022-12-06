// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

struct MyDappCellViewModel: Hashable {
    let imageUrl: URL?
    let name: String
    let domainName: String

    init(dapp: Bookmark) {
        self.domainName = URL(string: dapp.url)?.host ?? ""
        self.name = dapp.title
        self.imageUrl = Favicon.get(for: URL(string: dapp.url))
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
        return UIColor(red: 77, green: 77, blue: 77)
    }

    var domainNameColor: UIColor? {
        return Colors.appTint
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
