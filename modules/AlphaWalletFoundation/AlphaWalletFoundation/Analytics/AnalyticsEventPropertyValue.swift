// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

public protocol AnalyticsEventPropertyValue {
    var value: Any { get }
}

extension String: AnalyticsEventPropertyValue {
    public var value: Any {
        return self
    }
}
extension Int: AnalyticsEventPropertyValue {
    public var value: Any {
        return self
    }
}
extension UInt: AnalyticsEventPropertyValue {
    public var value: Any {
        return self
    }
}
extension Double: AnalyticsEventPropertyValue {
    public var value: Any {
        return self
    }
}
extension Float: AnalyticsEventPropertyValue {
    public var value: Any {
        return self
    }
}
extension Bool: AnalyticsEventPropertyValue {
    public var value: Any {
        return self
    }
}
extension Date: AnalyticsEventPropertyValue {
    public var value: Any {
        return self
    }
}
extension URL: AnalyticsEventPropertyValue {
    public var value: Any {
        return self
    }
}
extension AlphaWallet.Address: AnalyticsEventPropertyValue {
    public var value: Any {
        return self.eip55String
    }
}
extension Array: AnalyticsEventPropertyValue where Iterator.Element == Int {
    public var value: Any {
        self
    }
}
