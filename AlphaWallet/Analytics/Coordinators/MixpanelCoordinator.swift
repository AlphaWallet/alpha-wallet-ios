// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import Mixpanel

class MixpanelCoordinator: Coordinator {
    private let key: String
    private var mixpanelInstance: MixpanelInstance {
        Mixpanel.mainInstance()
    }

    var coordinators: [Coordinator] = []

    init(withKey key: String) {
        self.key = key
    }

    func start() {
        Mixpanel.initialize(token: key)
        mixpanelInstance.identify(distinctId: mixpanelInstance.distinctId)
    }

    func add(pushDeviceToken token: Data) {
        mixpanelInstance.people.addPushDeviceToken(token)
    }

    private func convertParameterToSdkSpecificVersion(_ parameter: AnalyticsEventPropertyValue) -> MixpanelType? {
        switch parameter {
        case let string as String:
            return string
        case let int as Int:
            return int
        case let uint as UInt:
            return uint
        case let double as Double:
            return double
        case let float as Float:
            return float
        case let bool as Bool:
            return bool
        case let date as Date:
            return date
        case let url as URL:
            return url
        case let address as AlphaWallet.Address:
            return address.eip55String
        case let address as AlphaWallet.Address:
            return address.eip55String

        default:
            return nil
        }
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
}

