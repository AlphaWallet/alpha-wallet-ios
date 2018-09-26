// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct CryptoKittyCAttributeCellViewModel {
    let name: String
    let value: String

    var image: UIImage {
        return R.image.cryptoKittyAttribute()!
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
