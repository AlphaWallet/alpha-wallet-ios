// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct BrowserHomeHeaderViewModel {
    var title: String

    var logo: UIImage? {
        return R.image.awLogoSmall()
    }

    var titleFont: UIFont? {
        return Fonts.regular(size: 20)
    }
}
