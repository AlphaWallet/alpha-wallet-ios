//
//  BartercardAnalytics.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 06.11.2020.
//

import Foundation
import UIKit

protocol AnalyticsServiceType: AnalyticsCoordinator {
    func applicationDidBecomeActive()
    func application(continue userActivity: NSUserActivity)
    func application(open url: URL, sourceApplication: String?, annotation: Any)
    func application(open url: URL, options: [UIApplication.OpenURLOptionsKey: Any])
    func application(didReceiveRemoteNotification userInfo: [AnyHashable: Any])

    func add(pushDeviceToken token: Data)
}

class AnalyticsService: NSObject, AnalyticsServiceType {
    private var mixpanelService: MixpanelCoordinator?
    private var config: Config

    init(config: Config = .init()) {
        self.config = config
        super.init()
        //NOTE: set default state of sending analytics events
        if self.config.sendAnalyticsEnabled == nil {
            self.config.sendAnalyticsEnabled = Features.isAnalyticsUIEnabled
        }
        if Constants.Credentials.analyticsKey.nonEmpty && !Environment.isTestFlight {
            mixpanelService = MixpanelCoordinator(withKey: Constants.Credentials.analyticsKey)
        }
    }

    func add(pushDeviceToken token: Data) {
        mixpanelService?.add(pushDeviceToken: token)
    }

    func applicationDidBecomeActive() {

    }

    func application(continue userActivity: NSUserActivity) {

    }

    func application(open url: URL, sourceApplication: String?, annotation: Any) {

    }

    func application(open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) {

    }

    func application(didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {

    }

    func log(navigation: AnalyticsNavigation, properties: [String: AnalyticsEventPropertyValue]?) {
        guard config.isSendAnalyticsEnabled else { return }
        mixpanelService?.log(navigation: navigation, properties: properties)
    }

    func log(action: AnalyticsAction, properties: [String: AnalyticsEventPropertyValue]?) {
        guard config.isSendAnalyticsEnabled else { return }
        mixpanelService?.log(action: action, properties: properties)
    }

    func log(error: AnalyticsError, properties: [String: AnalyticsEventPropertyValue]?) {
        guard config.isSendAnalyticsEnabled else { return }
        mixpanelService?.log(error: error, properties: properties)
    }

    func setUser(property: AnalyticsUserProperty, value: AnalyticsEventPropertyValue) {
        guard config.isSendAnalyticsEnabled else { return }
        mixpanelService?.setUser(property: property, value: value)
    }

    func incrementUser(property: AnalyticsUserProperty, by value: Int) {
        guard config.isSendAnalyticsEnabled else { return }
        mixpanelService?.incrementUser(property: property, by: value)
    }

    func incrementUser(property: AnalyticsUserProperty, by value: Double) {
        guard config.isSendAnalyticsEnabled else { return }
        mixpanelService?.incrementUser(property: property, by: value)
    }
}
