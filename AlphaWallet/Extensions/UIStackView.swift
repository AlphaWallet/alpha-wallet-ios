// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

extension UIStackView {
    public func addArrangedSubviews(_ views: [UIView]) {
        for each in views {
            addArrangedSubview(each)
        }
    }
}
