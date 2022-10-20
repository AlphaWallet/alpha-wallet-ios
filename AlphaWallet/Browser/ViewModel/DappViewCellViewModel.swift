// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

struct DappViewCellViewModel: Hashable {
    private let order: Int
    
    let imageUrl: URL?
    let title: String
    let domainName: String

    init(dapp: Bookmark) {
        self.order = dapp.order
        self.domainName = URL(string: dapp.url)?.host ?? ""
        self.title = dapp.title
        self.imageUrl = Favicon.get(for: URL(string: dapp.url))
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
        return Metrics.DappsHome.Icon.shadowOffset
    }

    var imageViewShadowOpacity: Float {
        return Metrics.DappsHome.Icon.shadowOpacity
    }

    var imageViewShadowRadius: CGFloat {
        return Metrics.DappsHome.Icon.shadowRadius
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
