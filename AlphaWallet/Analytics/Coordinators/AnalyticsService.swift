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

    override init() {
        super.init()
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
        mixpanelService?.log(navigation: navigation, properties: properties)
    }

    func log(action: AnalyticsAction, properties: [String: AnalyticsEventPropertyValue]?) {
        mixpanelService?.log(action: action, properties: properties)
    }

    func log(error: AnalyticsError, properties: [String: AnalyticsEventPropertyValue]?) {
        mixpanelService?.log(error: error, properties: properties)
    }

    func setUser(property: AnalyticsUserProperty, value: AnalyticsEventPropertyValue) {
        mixpanelService?.setUser(property: property, value: value)
    }

    func incrementUser(property: AnalyticsUserProperty, by value: Int) {
        mixpanelService?.incrementUser(property: property, by: value)
    }

    func incrementUser(property: AnalyticsUserProperty, by value: Double) {
        mixpanelService?.incrementUser(property: property, by: value)
    }
}
