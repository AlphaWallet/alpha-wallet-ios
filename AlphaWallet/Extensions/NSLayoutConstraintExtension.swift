//
//  NSLayoutConstraintExtension.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 20/4/22.
//

import Foundation
import UIKit

extension NSLayoutConstraint {
    func set(priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
