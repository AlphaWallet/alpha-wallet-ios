// Copyright SIX DAY LLC. All rights reserved.
import UIKit
import RealmSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    var window: UIWindow?
    private var appCoordinator: AppCoordinator!
    //This is separate coordinator for the protection of the sensitive information.
    private lazy var protectionCoordinator: ProtectionCoordinator = {
        return ProtectionCoordinator()
    }()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        print(Realm.Configuration().fileURL!)

        window = UIWindow(frame: UIScreen.main.bounds)
        do {
            let keystore = try EtherKeystore()
            appCoordinator = AppCoordinator(window: window!, keystore: keystore)
            appCoordinator.start()
        } catch {
            print("EtherKeystore init issue.")
        }
        protectionCoordinator.didFinishLaunchingWithOptions()

        return true
    }
    func applicationWillResignActive(_ application: UIApplication) {
        protectionCoordinator.applicationWillResignActive()
    }
    func applicationDidBecomeActive(_ application: UIApplication) {
        //Lokalise.shared.checkForUpdates { _, _ in }
        protectionCoordinator.applicationDidBecomeActive()
        appCoordinator.handleUniversalLinkInPasteboard()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        protectionCoordinator.applicationDidEnterBackground()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        protectionCoordinator.applicationWillEnterForeground()
    }

    func application(_ application: UIApplication, shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplicationExtensionPointIdentifier) -> Bool {
        if extensionPointIdentifier == UIApplicationExtensionPointIdentifier.keyboard {
            return false
        }
        return true
    }

    // Respond to URI scheme links
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey: Any] = [:]) -> Bool {
        return true
    }

    // Respond to Universal Links
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        var handled = false
        if let url = userActivity.webpageURL {
            handled = handleUniversalLink(url: url)
        }
        //TODO: if we handle other types of URLs, check if handled==false, then we pass the url to another handlers
        return true
    }

    @discardableResult private func handleUniversalLink(url: URL) -> Bool {
        let handled = appCoordinator.handleUniversalLink(url: url)
        return handled
    }
}
