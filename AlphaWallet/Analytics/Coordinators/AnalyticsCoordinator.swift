// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

protocol AnalyticsCoordinator {
    func log(navigation: AnalyticsNavigation, properties: [String: AnalyticsEventPropertyValue]?)
    func log(action: AnalyticsAction, properties: [String: AnalyticsEventPropertyValue]?)
    func log(error: AnalyticsError, properties: [String: AnalyticsEventPropertyValue]?)
    func setUser(property: AnalyticsUserProperty, value: AnalyticsEventPropertyValue)
    func incrementUser(property: AnalyticsUserProperty, by value: Int)
    func incrementUser(property: AnalyticsUserProperty, by value: Double)
}

extension AnalyticsCoordinator {
    func log(navigation: AnalyticsNavigation) {
        log(navigation: navigation, properties: nil)
    }

    func log(action: AnalyticsAction) {
        log(action: action, properties: nil)
    }

    func log(error: AnalyticsError) {
        log(error: error, properties: nil)
    }
}
