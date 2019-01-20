// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct DiscoverDappCellViewModel {
    let bookmarksStore: BookmarksStore
    let dapp: Dapp

    private var containsDapp: Bool {
        //TODO can we not loop? Or at least we can cache this value, no need to be a computed var
        for each in bookmarksStore.bookmarks {
            if each.url == dapp.url {
                return true
            }
        }
        return false
    }

    var isAddButtonHidden: Bool {
        return containsDapp
    }

    var isRemoveButtonHidden: Bool {
        return !containsDapp
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var imageUrl: URL? {
        return Favicon.get(for: URL(string: dapp.url))
    }

    var fallbackImage: UIImage? {
        return R.image.launch_icon()
    }

    var name: String {
        return dapp.name
    }

    var description: String {
        return dapp.description
    }

    var nameFont: UIFont {
        return Fonts.semibold(size: 12)!
    }

    var descriptionFont: UIFont {
        return Fonts.regular(size: 10)!
    }

    var nameColor: UIColor? {
        return UIColor(red: 77, green: 77, blue: 77)
    }

    var descriptionColor: UIColor? {
        return UIColor(red: 77, green: 77, blue: 77)
    }

    var addRemoveButtonFont: UIFont {
        return Fonts.semibold(size: 12)!
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
