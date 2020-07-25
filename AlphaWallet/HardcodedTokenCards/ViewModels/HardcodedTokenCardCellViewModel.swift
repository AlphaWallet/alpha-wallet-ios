// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import UIKit

struct HardcodedTokenCardCellViewModel {
    let values: [AttributeId: AssetInternalValue]
    let title: String
    let formatter: HardcodedTokenCardRowFormatter
    let progressBlock: HardcodedTokenCardRowFloatBlock?

    var labelColor: UIColor {
        R.color.dove()!
    }

    var labelFont: UIFont? {
        Fonts.regular(size: 13)
    }

    var valueColor: UIColor {
        R.color.black()!
    }

    var valueFont: UIFont? {
        Fonts.regular(size: 17)
    }

    var value: String {
        formatter(values)
    }

    var progressValue: Float? {
        progressBlock?(values)
    }
}
