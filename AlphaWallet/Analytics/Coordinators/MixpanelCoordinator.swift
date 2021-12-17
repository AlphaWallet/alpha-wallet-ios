// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import Mixpanel

class MixpanelCoordinator {
    private var mixpanelInstance: MixpanelInstance {
        Mixpanel.mainInstance()
    }

    init(withKey key: String) {
        Mixpanel.initialize(token: key)
        mixpanelInstance.identify(distinctId: mixpanelInstance.distinctId)
    }

    func add(pushDeviceToken token: Data) {
        mixpanelInstance.people.addPushDeviceToken(token)
    }

    func convertParameterToSdkSpecificVersion(_ parameter: AnalyticsEventPropertyValue) -> MixpanelType? {
        return parameter.value as? MixpanelType
    }
}

extension MixpanelCoordinator: AnalyticsCoordinator {
    func log(navigation: AnalyticsNavigation, properties: [String: AnalyticsEventPropertyValue]?) {
        let props: Properties? = properties?.compactMapValues(convertParameterToSdkSpecificVersion)
        mixpanelInstance.track(event: navigation.rawValue, properties: props)
    }

    func log(action: AnalyticsAction, properties: [String: AnalyticsEventPropertyValue]?) {
        let props: Properties? = properties?.compactMapValues(convertParameterToSdkSpecificVersion)
        mixpanelInstance.track(event: action.rawValue, properties: props)
    }

    func log(error: AnalyticsError, properties: [String: AnalyticsEventPropertyValue]?) {
        let props: Properties? = properties?.compactMapValues(convertParameterToSdkSpecificVersion)
        mixpanelInstance.track(event: error.rawValue, properties: props)
    }

    func setUser(property: AnalyticsUserProperty, value: AnalyticsEventPropertyValue) {
        guard let value = convertParameterToSdkSpecificVersion(value) else { return }
        mixpanelInstance.people.set(property: property.rawValue, to: value)
    }

    func incrementUser(property: AnalyticsUserProperty, by value: Int) {
        mixpanelInstance.people.increment(property: property.rawValue, by: Double(value))
    }

    func incrementUser(property: AnalyticsUserProperty, by value: Double) {
        mixpanelInstance.people.increment(property: property.rawValue, by: value)
    }
}
