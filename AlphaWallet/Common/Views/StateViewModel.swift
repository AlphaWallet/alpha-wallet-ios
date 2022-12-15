// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

struct StateViewModel {

    var titleTextColor: UIColor {
        return Configuration.Color.Semantic.defaultForegroundText
   }

    var titleFont: UIFont {
        return Fonts.semibold(size: 18)
    }

    var descriptionTextColor: UIColor {
        return Configuration.Color.Semantic.defaultForegroundText
    }

    var descriptionFont: UIFont {
        return Fonts.regular(size: 16)
    }

    var stackSpacing: CGFloat {
        return 30
    }
}
