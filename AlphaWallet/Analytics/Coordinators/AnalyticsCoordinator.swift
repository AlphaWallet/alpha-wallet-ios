// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

protocol AnalyticsCoordinator {
    func log(navigation: AnalyticsNavigation, properties: [String: AnalyticsEventPropertyValue]?)
    func log(action: AnalyticsAction, properties: [String: AnalyticsEventPropertyValue]?)
}

extension AnalyticsCoordinator {
    func log(navigation: AnalyticsNavigation) {
        log(navigation: navigation, properties: nil)
    }

    func log(action: AnalyticsAction) {
        log(action: action, properties: nil)
    }
}
