// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

extension Collection where Element == UIView {
    // swiftlint:disable all
    var alpha: CGFloat {
        set {
            for each in self {
                each.alpha = newValue
            }
        }
        get {
            return 1
        }
    }
    // swiftlint:enable all
    
    func hideAll() {
        for each in self {
            each.isHidden = true
        }
    }

    func showAll() {
        for each in self {
            each.isHidden = false
        }
    }
}
