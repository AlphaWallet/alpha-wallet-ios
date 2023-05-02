// Copyright © 2022 Stormbird PTE. LTD.

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private var appCoordinator: AppCoordinator!
    private var application: Application!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        self.application = Application.shared

        //Keep this log because it's really useful for debugging things without requiring a new TestFlight/app store submission
        NSLog("Application launched with launchOptions: \(String(describing: launchOptions))")
        appCoordinator = AppCoordinator.create(application: self.application)
        appCoordinator.start(launchOptions: launchOptions)

        return true
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem) async -> Bool {
        await self.application.applicationPerformActionFor(shortcutItem)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        appCoordinator.applicationWillResignActive()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        appCoordinator.applicationDidBecomeActive()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        appCoordinator.applicationDidEnterBackground()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        appCoordinator.applicationWillEnterForeground()
    }

    func application(_ application: UIApplication, shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplication.ExtensionPointIdentifier) -> Bool {
        return self.application.applicationShouldAllowExtensionPointIdentifier(extensionPointIdentifier)
    }

    // URI scheme links and AirDrop
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        //Keep this log because it's really useful for debugging things without requiring a new TestFlight/app store submission
        NSLog("Application open url: \(url.absoluteString) options: \(options)")
        return self.application.applicationOpenUrl(url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        NSLog("Application open userActivity: \(userActivity)")
        return self.application.applicationContinueUserActivity(userActivity, restorationHandler: restorationHandler)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        //no op
    }
}

extension UIApplicationShortcutItem: @unchecked Sendable {}
