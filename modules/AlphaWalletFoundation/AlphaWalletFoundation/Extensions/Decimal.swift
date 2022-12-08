// Copyright SIX DAY LLC. All rights reserved.

import Foundation

extension Decimal {
    public var doubleValue: Double {
        return Double(description) ?? .nan
    }
}
