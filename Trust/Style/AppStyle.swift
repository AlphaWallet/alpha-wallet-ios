// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import Eureka

func applyStyle() {

    if #available(iOS 11, *) {
    } else {
        UINavigationBar.appearance().isTranslucent = false
    }
    UIWindow.appearance().tintColor = Colors.appBackground
    UINavigationBar.appearance().tintColor = Colors.appWhite
    UINavigationBar.appearance().setBackgroundImage(.filled(with: Colors.appBackground), for: .default)
    UINavigationBar.appearance().shadowImage = UIImage()
    UINavigationBar.appearance().backIndicatorImage = R.image.backWhite()
    UINavigationBar.appearance().backIndicatorTransitionMaskImage = R.image.backWhite()
    UINavigationBar.appearance().titleTextAttributes = [
        .foregroundColor: Colors.appWhite,
        .font: Fonts.light(size: 25)
    ]

    //We could have set the backBarButtonItem with an empty title for every view controller, but we don't have a place to do it for Eureka view controllers. Using appearance here, while a hack is still more convenient though, since we don't have to do it for every view controller instance
    UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(UIOffset(horizontal: -200, vertical: 0), for: .default)

    UIToolbar.appearance().tintColor = Colors.appBackground

    UITextField.appearance().tintColor = Colors.blue

    UIRefreshControl.appearance().tintColor = Colors.appWhite

    UIImageView.appearance().tintColor = Colors.lightBlue
    UIImageView.appearance(whenContainedInInstancesOf: [BrowserNavigationBar.self]).tintColor = .white

    BalanceTitleView.appearance().titleTextColor = UIColor.white
    BalanceTitleView.appearance().subTitleTextColor = UIColor(white: 0.9, alpha: 1)
}

func applyStyle(viewController: UIViewController) {
	// See use of setBackButtonTitlePositionAdjustment(:for:) above
//    viewController.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
}

struct Colors {
    static let darkBlue = UIColor(hex: "3375BB")
    static let blue = UIColor(hex: "2e91db")
    static let red = UIColor(hex: "f7506c")
    static let veryLightRed = UIColor(hex: "FFF4F4")
    static let veryLightOrange = UIColor(hex: "FFECC9")
    static let green = UIColor(hex: "2fbb4f")
    static let lightGray = UIColor.lightGray
    static let veryLightGray = UIColor(hex: "F6F6F6")
    static let gray = UIColor.gray
    static let darkGray = UIColor(hex: "606060")
    static let black = UIColor(hex: "313849")
    static let lightBlack = UIColor(hex: "313849")
    static let lightBlue = UIColor(hex: "007aff")
    static let appBackground = UIColor(red: 84, green: 193, blue: 227)
    static let appWhite = UIColor.white
    static let appText = UIColor(red: 47, green: 47, blue: 47)
    static let appHighlightGreen = UIColor(red: 117, green: 185, blue: 67)
    static let appLightButtonSeparator = UIColor(red: 255, green: 255, blue: 255, alpha: 0.2)
}

struct StyleLayout {
    static let sideMargin: CGFloat = 15
}

struct Fonts {
    static let labelSize: CGFloat = 18
    static let buttonSize: CGFloat = 20

    static func light(size: CGFloat) -> UIFont? {
        return UIFont(resource: R.font.sourceSansProLight, size: size)
    }
    static func regular(size: CGFloat) -> UIFont? {
        return UIFont(resource: R.font.sourceSansProRegular, size: size)
    }
    static func semibold(size: CGFloat) -> UIFont? {
        return UIFont(resource: R.font.sourceSansProSemibold, size: size)
    }
    static func bold(size: CGFloat) -> UIFont? {
        return UIFont(resource: R.font.sourceSansProBold, size: size)
    }
}
