// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

protocol AnalyticsEventPropertyValue {
}

extension String: AnalyticsEventPropertyValue {
}
extension Int: AnalyticsEventPropertyValue {
}
extension UInt: AnalyticsEventPropertyValue {
}
extension Double: AnalyticsEventPropertyValue {
}
extension Float: AnalyticsEventPropertyValue {
}
extension Bool: AnalyticsEventPropertyValue {
}
extension Date: AnalyticsEventPropertyValue {
}
extension URL: AnalyticsEventPropertyValue {
}
extension AlphaWallet.Address: AnalyticsEventPropertyValue {
}
