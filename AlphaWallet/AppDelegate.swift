// Copyright © 2022 Stormbird PTE. LTD.

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private var appCoordinator: AppCoordinator!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        do {
            //Keep this log because it's really useful for debugging things without requiring a new TestFlight/app store submission
            NSLog("Application launched with launchOptions: \(String(describing: launchOptions))")
            appCoordinator = try AppCoordinator.create()
            appCoordinator.start(launchOptions: launchOptions)
        } catch {
            //no-op
        }

        return true
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        appCoordinator.applicationPerformActionFor(shortcutItem, completionHandler: completionHandler)
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
        return appCoordinator.applicationShouldAllowExtensionPointIdentifier(extensionPointIdentifier)
    }

    // URI scheme links and AirDrop
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        //Keep this log because it's really useful for debugging things without requiring a new TestFlight/app store submission
        NSLog("Application open url: \(url.absoluteString) options: \(options)")
        return appCoordinator.applicationOpenUrl(url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        NSLog("Application open userActivity: \(userActivity)")
        return appCoordinator.applicationContinueUserActivity(userActivity, restorationHandler: restorationHandler)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        //no op
    }
}
