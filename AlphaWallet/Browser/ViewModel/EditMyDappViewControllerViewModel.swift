// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct EditMyDappViewControllerViewModel {
    let dapp: Bookmark

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var imageShadowColor: UIColor {
        return Metrics.DappsHome.Icon.shadowColor
    }

    var imageShadowOffset: CGSize {
        return Metrics.DappsHome.Icon.shadowOffset
    }

    var imageShadowOpacity: Float {
        return Metrics.DappsHome.Icon.shadowOpacity
    }

    var imageShadowRadius: CGFloat {
        return Metrics.DappsHome.Icon.shadowRadius
    }

    var imageBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var imagePlaceholder: UIImage {
        return R.image.launch_icon()!
    }

    var imageUrl: URL? {
        return Favicon.get(for: URL(string: dapp.url))
    }

    var screenTitle: String {
        return R.string.localizable.dappBrowserMyDappsEdit()
    }

    var screenFont: UIFont {
        return Fonts.semibold(size: 20)!
    }

    var titleColor: UIColor {
        return .init(red: 71, green: 71, blue: 71)
    }

    var titleFont: UIFont {
        return Fonts.semibold(size: 16)!
    }

    var titleText: String {
        return R.string.localizable.dappBrowserMyDappsEditTitleLabel()
    }

    var urlColor: UIColor {
        return .init(red: 71, green: 71, blue: 71)
    }

    var urlFont: UIFont {
        return Fonts.semibold(size: 16)!
    }

    var urlText: String {
        return R.string.localizable.dappBrowserMyDappsEditUrlLabel()
    }

    var titleTextFieldBorderStyle: UITextField.BorderStyle {
        return .roundedRect
    }

    var titleTextFieldBorderWidth: CGFloat {
        return 0.5
    }

    var titleTextFieldBorderColor: UIColor {
        return .init(red: 112, green: 112, blue: 112)
    }

    var titleTextFieldCornerRadius: CGFloat {
        return 7
    }

    var titleTextFieldFont: UIFont {
        return Fonts.light(size: 16)!
    }

    var titleTextFieldText: String {
        return dapp.title
    }

    var urlTextFieldBorderStyle: UITextField.BorderStyle {
        return .roundedRect
    }

    var urlTextFieldBorderWidth: CGFloat {
        return 0.5
    }

    var urlTextFieldBorderColor: UIColor {
        return .init(red: 112, green: 112, blue: 112)
    }

    var urlTextFieldCornerRadius: CGFloat {
        return 7
    }

    var urlTextFieldFont: UIFont {
        return Fonts.light(size: 16)!
    }

    var urlTextFieldText: String {
        return dapp.url
    }

    var saveButtonTitleColor: UIColor {
        return Colors.appWhite
    }

    var saveButtonBackgroundColor: UIColor {
        return Colors.appHighlightGreen
    }

    var saveButtonFont: UIFont {
        return Fonts.regular(size: 20)!
    }

    var saveButtonTitle: String {
        return R.string.localizable.save()
    }

    var saveButtonCornerRadius: CGFloat {
        return 16
    }

    var cancelButtonTitleColor: UIColor {
        return Colors.appWhite
    }

    var cancelButtonFont: UIFont {
        return Fonts.regular(size: 20)!
    }

    var cancelButtonTitle: String {
        return R.string.localizable.cancel()
    }
}
