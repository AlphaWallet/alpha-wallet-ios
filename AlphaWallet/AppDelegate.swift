// Copyright SIX DAY LLC. All rights reserved.
import UIKit
import RealmSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    var window: UIWindow?
    var appCoordinator: AppCoordinator!
    var coordinator: AppCoordinator!
    // Need to retain while still processing
    var universalLinkCoordinator: UniversalLinkCoordinator!
    //This is separate coordinator for the protection of the sensitive information.
    lazy var protectionCoordinator: ProtectionCoordinator = {
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
        //TODO better to move into AppCoordinator or InCoordinator. Ditto for tap to import universal link.
        let universalLinkPasteboardCoordinator = UniversalLinkInPasteboardCoordinator()
        universalLinkPasteboardCoordinator.delegate = self
        universalLinkPasteboardCoordinator.start()
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
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
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

    private func handleUniversalLink(url: URL) -> Bool {
        appCoordinator.createInitialWallet()
        appCoordinator.closeWelcomeWindow()
        universalLinkCoordinator = UniversalLinkCoordinator(config: Config())
        universalLinkCoordinator.ethPrice = appCoordinator.ethPrice
        universalLinkCoordinator.ethBalance = appCoordinator.ethBalance
        universalLinkCoordinator.delegate = self
        universalLinkCoordinator.start()
        let handled = universalLinkCoordinator.handleUniversalLink(url: url)
        if !handled {
            universalLinkCoordinator = nil
        }
        return handled
    }
}

extension AppDelegate: UniversalLinkCoordinatorDelegate {

    func viewControllerForPresenting(in coordinator: UniversalLinkCoordinator) -> UIViewController? {
        if var top = window?.rootViewController {
            while let vc = top.presentedViewController {
                top = vc
            }
            return top
        } else {
            return nil
        }
    }

    func importPaidSignedOrder(signedOrder: SignedOrder, tokenObject: TokenObject, completion: @escaping (Bool) -> Void) {
        appCoordinator.importPaidSignedOrder(signedOrder: signedOrder, tokenObject: tokenObject, completion: completion)
    }

    func completed(in coordinator: UniversalLinkCoordinator) {
        universalLinkCoordinator = nil
    }
}

extension AppDelegate: UniversalLinkInPasteboardCoordinatorDelegate {
    func importUniversalLink(url: URL, for coordinator: UniversalLinkInPasteboardCoordinator) {
        guard universalLinkCoordinator == nil else { return }
        handleUniversalLink(url: url)
    }
}
