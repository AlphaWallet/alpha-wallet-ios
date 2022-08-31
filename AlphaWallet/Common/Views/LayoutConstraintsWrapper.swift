// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

///This let us do this do effectively this:
///
///NSLayoutConstraint.activate([
///    constraintsArray1,
///    constraintsArray2,
///    constraint3,
///    constraint4,
///    constraint5,
///])
///
///Alternatives involve appending of arrays which ends up with code that is hard to indent
protocol LayoutConstraintsWrapper {
    var constraints: [NSLayoutConstraint] { get }
}

extension Array: LayoutConstraintsWrapper where Element: NSLayoutConstraint {
    var constraints: [NSLayoutConstraint] {
        return self
    }
}

extension NSLayoutConstraint: LayoutConstraintsWrapper {
    var constraints: [NSLayoutConstraint] {
        return [self]
    }
}

extension NSLayoutConstraint {
    class func activate(_ constraints: [LayoutConstraintsWrapper]) {
        activate(constraints.flatMap { $0.constraints })
    }
}
