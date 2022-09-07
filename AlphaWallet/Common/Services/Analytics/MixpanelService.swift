// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import AlphaWalletFoundation
import Mixpanel

public class MixpanelService {
    private var mixpanelInstance: MixpanelInstance {
        Mixpanel.mainInstance()
    }

    public init(withKey key: String) {
        Mixpanel.initialize(token: key)
        mixpanelInstance.identify(distinctId: mixpanelInstance.distinctId)
    }

    public func convertParameterToSdkSpecificVersion(_ parameter: AnalyticsEventPropertyValue) -> MixpanelType? {
        return parameter.value as? MixpanelType
    }
}

extension MixpanelService: AnalyticsLogger {
    public func log(navigation: AnalyticsNavigation, properties: [String: AnalyticsEventPropertyValue]?) {
        let props: Properties? = properties?.compactMapValues(convertParameterToSdkSpecificVersion)
        mixpanelInstance.track(event: navigation.rawValue, properties: props)
    }

    public func log(action: AnalyticsAction, properties: [String: AnalyticsEventPropertyValue]?) {
        let props: Properties? = properties?.compactMapValues(convertParameterToSdkSpecificVersion)
        mixpanelInstance.track(event: action.rawValue, properties: props)
    }

    public func log(stat: AnalyticsStat, properties: [String: AnalyticsEventPropertyValue]?) {
        let props: Properties? = properties?.compactMapValues(convertParameterToSdkSpecificVersion)
        mixpanelInstance.track(event: stat.rawValue, properties: props)
    }

    public func log(error: AnalyticsError, properties: [String: AnalyticsEventPropertyValue]?) {
        let props: Properties? = properties?.compactMapValues(convertParameterToSdkSpecificVersion)
        mixpanelInstance.track(event: error.rawValue, properties: props)
    }

    public func setUser(property: AnalyticsUserProperty, value: AnalyticsEventPropertyValue) {
        guard let value = convertParameterToSdkSpecificVersion(value) else { return }
        mixpanelInstance.people.set(property: property.rawValue, to: value)
    }

    public func incrementUser(property: AnalyticsUserProperty, by value: Int) {
        mixpanelInstance.people.increment(property: property.rawValue, by: Double(value))
    }

    public func incrementUser(property: AnalyticsUserProperty, by value: Double) {
        mixpanelInstance.people.increment(property: property.rawValue, by: value)
    }
}
