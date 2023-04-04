// Copyright SIX DAY LLC. All rights reserved.

import Foundation

extension Decimal {
    public var doubleValue: Double {
        return Double(description) ?? .nan
    }

    public var floatValue: Float? {
        guard (Float.min ... Float.max).contains(doubleValue) else { return nil }
        return Float(doubleValue)
    }
}


public extension Float {
    /// Max double value.
    static var max: Double {
        return Double(greatestFiniteMagnitude)
    }

    /// Min double value.
    static var min: Double {
        return Double(-greatestFiniteMagnitude)
    }
}
