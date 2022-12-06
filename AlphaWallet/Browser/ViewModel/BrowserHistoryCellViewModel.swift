// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

struct BrowserHistoryCellViewModel: Hashable {
    let history: BrowserHistoryRecord

    var imageUrl: URL? { return Favicon.get(for: history.url) }
    var name: String { return history.title }
    var url: String { return history.url.absoluteString }

    init(history: BrowserHistoryRecord) {
        self.history = history
    }

    var backgroundColor: UIColor {
        return Configuration.Color.Semantic.defaultViewBackground
    }

    var fallbackImage: UIImage? {
        return R.image.iconsTokensPlaceholder()
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
