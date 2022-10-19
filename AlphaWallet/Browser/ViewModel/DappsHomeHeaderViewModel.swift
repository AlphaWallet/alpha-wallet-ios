// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct BrowserHomeHeaderViewModel {
    var title: String

    var backgroundColor: UIColor {
        return Configuration.Color.Semantic.defaultViewBackground
    }

    var logo: UIImage? {
        return R.image.launch_icon()
    }

    var titleFont: UIFont? {
        return Fonts.regular(size: 20)
    }
}
