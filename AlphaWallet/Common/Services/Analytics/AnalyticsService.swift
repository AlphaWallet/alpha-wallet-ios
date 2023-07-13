// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import AlphaWalletFoundation

public final class AnalyticsService: NSObject, AnalyticsServiceType {
    private var mixpanelService: MixpanelService?
    private var config: Config

    public init(config: Config = .init()) {
        self.config = config
        super.init()
        //NOTE: set default state of sending analytics events
        if self.config.sendAnalyticsEnabled == nil {
            self.config.sendAnalyticsEnabled = Features.current.isAvailable(.isAnalyticsUIEnabled)
        }
        if Constants.Credentials.analyticsKey.nonEmpty && !Environment.isTestFlight {
            mixpanelService = MixpanelService(withKey: Constants.Credentials.analyticsKey)
        }
    }

    public func applicationDidBecomeActive() {

    }

    public func application(continue userActivity: NSUserActivity) {

    }

    public func application(open url: URL, sourceApplication: String?, annotation: Any) {

    }

    public func application(open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) {

    }

    public func application(didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {

    }

    public func log(navigation: AnalyticsNavigation, properties: [String: AnalyticsEventPropertyValue]?) {
        guard config.isSendAnalyticsEnabled else { return }
        mixpanelService?.log(navigation: navigation, properties: properties)
    }

    public func log(action: AnalyticsAction, properties: [String: AnalyticsEventPropertyValue]?) {
        guard config.isSendAnalyticsEnabled else { return }
        mixpanelService?.log(action: action, properties: properties)
    }

    public func log(stat: AnalyticsStat, properties: [String: AnalyticsEventPropertyValue]?) {
        guard config.isSendAnalyticsEnabled else { return }
        mixpanelService?.log(stat: stat, properties: properties)
    }

    public func log(error: AnalyticsError, properties: [String: AnalyticsEventPropertyValue]?) {
        guard config.isSendAnalyticsEnabled else { return }
        mixpanelService?.log(error: error, properties: properties)
    }

    public func setUser(property: AnalyticsUserProperty, value: AnalyticsEventPropertyValue) {
        guard config.isSendAnalyticsEnabled else { return }
        mixpanelService?.setUser(property: property, value: value)
    }

    public func incrementUser(property: AnalyticsUserProperty, by value: Int) {
        guard config.isSendAnalyticsEnabled else { return }
        mixpanelService?.incrementUser(property: property, by: value)
    }

    public func incrementUser(property: AnalyticsUserProperty, by value: Double) {
        guard config.isSendAnalyticsEnabled else { return }
        mixpanelService?.incrementUser(property: property, by: value)
    }
}
