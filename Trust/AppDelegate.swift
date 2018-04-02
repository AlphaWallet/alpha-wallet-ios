// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import Lokalise
import Branch
import RealmSwift
import Alamofire

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    var window: UIWindow?
    var coordinator: AppCoordinator!
    //This is separate coordinator for the protection of the sensitive information.
    lazy var protectionCoordinator: ProtectionCoordinator = {
        return ProtectionCoordinator()
    }()
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        print(Realm.Configuration().fileURL!)

        window = UIWindow(frame: UIScreen.main.bounds)
        do {
            let keystore = try EtherKeystore()
            coordinator = AppCoordinator(window: window!, keystore: keystore)
            coordinator.start()
        } catch {
            print("EtherKeystore init issue.")
        }
        protectionCoordinator.didFinishLaunchingWithOptions()

        Branch.getInstance().initSession(launchOptions: launchOptions, andRegisterDeepLinkHandler: {params, error in
            if error == nil {
                print("params: %@", params as? [String: AnyObject] ?? {})
            }
        })
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        coordinator.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken: deviceToken)
    }
    func applicationWillResignActive(_ application: UIApplication) {
        protectionCoordinator.applicationWillResignActive()
    }
    func applicationDidBecomeActive(_ application: UIApplication) {
        Lokalise.shared.checkForUpdates { _, _ in }
        protectionCoordinator.applicationDidBecomeActive()
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
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        let branchHandled = Branch.getInstance().application(application,
                                                             open: url,
                                                             sourceApplication: sourceApplication,
                                                             annotation: annotation
        )
        if !branchHandled {
            // If not handled by Branch, do other deep link routing for the Facebook SDK, Pinterest SDK, etc

        }
        // do other deep link routing for the Facebook SDK, Pinterest SDK, etc
        return true
    }

    // Respond to Universal Links
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([Any]?) -> Void) -> Bool
    {
        Branch.getInstance().continue(userActivity)

        let url = userActivity.webpageURL

        if(url?.description.contains(UniversalLinkHandler().urlPrefix))!
        {
            let keystore = try! EtherKeystore()
            let signedOrder = UniversalLinkHandler().parseURL(url: (url?.description)!)
            let signature = signedOrder.signature.substring(from: 2)

	    // form the json string out of the order for the paymaster server
	    // James S. wrote
            let indices = signedOrder.order.indices
            var indicesStringEncoded = ""
	    
            for i in 0...indices.count - 1 {
                indicesStringEncoded += String(indices[i]) + ","
            }
            //cut off last comma
            indicesStringEncoded = indicesStringEncoded.substring(from: indicesStringEncoded.count - 1)

            let parameters: Parameters = [
                "address" : keystore.recentlyUsedWallet?.address.description,
                "indices": indicesStringEncoded,
                "v" : signature.substring(from: 128),
                "r": "0x" + signature.substring(with: Range(uncheckedBounds: (0, 64))),
                "s": "0x" + signature.substring(with: Range(uncheckedBounds: (64, 128)))
            ]
            let query = UniversalLinkHandler.paymentServer

            Alamofire.request(
                    query,
                    method: .post,
                    parameters: parameters
            ).responseJSON {
                result in
		// TODO handle http response
                print(result)
            }
        }
        return true
    }
}
