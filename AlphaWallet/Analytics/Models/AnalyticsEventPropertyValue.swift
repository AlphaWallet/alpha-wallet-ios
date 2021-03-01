// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

protocol AnalyticsEventPropertyValue {
    var value: Any { get }
}

extension String: AnalyticsEventPropertyValue {
    var value: Any {
        return self
    }
}
extension Int: AnalyticsEventPropertyValue {
    var value: Any {
        return self
    }
}
extension UInt: AnalyticsEventPropertyValue {
    var value: Any {
        return self
    }
}
extension Double: AnalyticsEventPropertyValue {
    var value: Any {
        return self
    }
}
extension Float: AnalyticsEventPropertyValue {
    var value: Any {
        return self
    }
}
extension Bool: AnalyticsEventPropertyValue {
    var value: Any {
        return self
    }
}
extension Date: AnalyticsEventPropertyValue {
    var value: Any {
        return self
    }
}
extension URL: AnalyticsEventPropertyValue {
    var value: Any {
        return self
    }
}
extension AlphaWallet.Address: AnalyticsEventPropertyValue {
    var value: Any {
        return self.eip55String
    }
}
extension Array: AnalyticsEventPropertyValue where Iterator.Element == Int {
    var value: Any {
        self
    }
}
