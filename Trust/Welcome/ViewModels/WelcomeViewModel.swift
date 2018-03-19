// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct WelcomeViewModel {

    var title: String {
        return "Welcome"
    }

    var backgroundColor: UIColor {
        return .white
    }

    var pageIndicatorTintColor: UIColor {
        return UIColor(red: 216, green: 216, blue: 216)
    }

    var currentPageIndicatorTintColor: UIColor {
        return UIColor(red: 183, green: 183, blue: 183)
    }

    var numberOfPages = 0
    var currentPage = 0
}
