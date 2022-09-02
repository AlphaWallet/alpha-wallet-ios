// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

public protocol AnalyticsLogger {
    func log(navigation: AnalyticsNavigation, properties: [String: AnalyticsEventPropertyValue]?)
    func log(action: AnalyticsAction, properties: [String: AnalyticsEventPropertyValue]?)
    func log(stat: AnalyticsStat, properties: [String: AnalyticsEventPropertyValue]?)
    func log(error: AnalyticsError, properties: [String: AnalyticsEventPropertyValue]?)
    func setUser(property: AnalyticsUserProperty, value: AnalyticsEventPropertyValue)
    func incrementUser(property: AnalyticsUserProperty, by value: Int)
    func incrementUser(property: AnalyticsUserProperty, by value: Double)
}

extension AnalyticsLogger {
    public func log(navigation: AnalyticsNavigation) {
        log(navigation: navigation, properties: nil)
    }

    public func log(action: AnalyticsAction) {
        log(action: action, properties: nil)
    }

    public func log(stat: AnalyticsStat) {
        log(stat: stat, properties: nil)
    }

    public func log(error: AnalyticsError) {
        log(error: error, properties: nil)
    }
}
