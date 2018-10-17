// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct OpenSeaNonFungibleTokenAttributeCellViewModel {
    let name: String
    let value: String

    var image: UIImage {
        return R.image.openSeaNonFungibleAttribute()!
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var nameFont: UIFont {
        return Fonts.light(size: 12)!
    }

    var valueFont: UIFont {
        return Fonts.semibold(size: 12)!
    }
}
