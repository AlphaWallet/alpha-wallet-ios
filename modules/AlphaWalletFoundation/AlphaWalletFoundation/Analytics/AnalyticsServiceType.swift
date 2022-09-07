//
//  AnalyticsServiceType.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 07.09.2022.
//

import Foundation

public protocol AnalyticsServiceType: AnalyticsLogger {
    func applicationDidBecomeActive()
    func application(continue userActivity: NSUserActivity)
    func application(open url: URL, sourceApplication: String?, annotation: Any)
    func application(open url: URL, options: [UIApplication.OpenURLOptionsKey: Any])
    func application(didReceiveRemoteNotification userInfo: [AnyHashable: Any])
}
