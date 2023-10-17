// Copyright © 2022 Stormbird PTE. LTD.

import UIKit
import AlphaWalletNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private var appCoordinator: AppCoordinator!
    private var application: Application!
    //NOTE: create backgroundTaskService as soon as possible, code might not be executed when task get created too late
    private let backgroundTaskService: BackgroundTaskService = BackgroundTaskServiceImplementation()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        //Keep this log because it's really useful for debugging things without requiring a new TestFlight/app store submission
        NSLog("--- Application launched with launchOptions: \(String(describing: launchOptions)) with documents directory: \(URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]))")

        self.application = Application.shared
        UNUserNotificationCenter.current().delegate = self

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

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        self.application.pushNotificationsService.register(deviceToken: .success(deviceToken))
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        self.application.pushNotificationsService.register(deviceToken: .failure(error))
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        NSLog("Application receive remote notification: \(userInfo)")

        let task: BackgroundTaskIdentifier?
        switch UIApplication.shared.applicationState {
        case .background:
            task = backgroundTaskService.startTask()
        default:
            task = nil
        }
        let result = await self.application.pushNotificationsService.handle(remoteNotification: userInfo)
        if let task = task {
            backgroundTaskService.endTask(with: task)
        }

        return result
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        await application.pushNotificationsService.userNotificationCenter(center, willPresent: notification)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await application.pushNotificationsService.userNotificationCenter(center, didReceive: response)
    }
}

extension UIApplicationShortcutItem: @unchecked Sendable {}
