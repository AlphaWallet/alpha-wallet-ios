// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

extension Collection where Element == UIView {
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
