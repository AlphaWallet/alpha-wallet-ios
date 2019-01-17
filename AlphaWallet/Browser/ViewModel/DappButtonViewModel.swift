// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct DappButtonViewModel {
    var font: UIFont? {
        return Fonts.semibold(size: 10)
    }

    var textColor: UIColor? {
        return .init(red: 77, green: 77, blue: 77)
    }

    let image: UIImage?
    let title: String
}
