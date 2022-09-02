// Copyright SIX DAY LLC. All rights reserved.

import Foundation

extension NSObject {
    public var className: String {
        return String(describing: type(of: self)).components(separatedBy: ".").last!
    }

    public class var className: String {
        return String(describing: self).components(separatedBy: ".").last!
    }
}
