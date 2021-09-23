// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct DappButtonViewModel {
    var font: UIFont? {
        return Fonts.regular(size: 13)
    }

    var textColor: UIColor? {
        return R.color.dove()
    }

    var imageForEnabledMode: UIImage? {
        return image
    }

    var imageForDisabledMode: UIImage? {
        return image?.withMonoEffect
    }

    let image: UIImage?
    let title: String
}
