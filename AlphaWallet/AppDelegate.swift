// Copyright SIX DAY LLC. All rights reserved.
import UIKit
import AlphaWalletAddress
import AlphaWalletFoundation 

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    var window: UIWindow?
    private var appCoordinator: AppCoordinator!
    //This is separate coordinator for the protection of the sensitive information.
    private lazy var protectionCoordinator: ProtectionCoordinator = {
        return ProtectionCoordinator()
    }()
    private lazy var reportProvider: ReportProvider = {
        let provider = ReportProvider()
        guard !isRunningTests() && isAlphaWallet() else { return provider }
        if let service = AlphaWallet.FirebaseReportService() {
            provider.register(service)
        }
        return provider
    }()
    private let addressStorage = FileAddressStorage()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        applyStyle()
        window = UIWindow(frame: UIScreen.main.bounds)

        do {
            if Features.default.isAvailable(.isFirebaseEnabled) {
                reportProvider.start()
            }

            register(addressStorage: addressStorage)
            register(crashlytics: AlphaWallet.FirebaseCrashlyticsReporter())

            let analytics = AnalyticsService()
            let walletAddressesStore: WalletAddressesStore = EtherKeystore.migratedWalletAddressesStore(userDefaults: .standardOrForTests)
            var keystore: Keystore = try EtherKeystore(walletAddressesStore: walletAddressesStore, analytics: analytics)

            let navigationController: UINavigationController = .withOverridenBarAppearence()
            navigationController.view.backgroundColor = Colors.appWhite

            appCoordinator = try AppCoordinator(window: window!, analytics: analytics, keystore: keystore, walletAddressesStore: walletAddressesStore, navigationController: navigationController)
            keystore.delegate = appCoordinator
            appCoordinator.start()

            if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem, shortcutItem.type == Constants.launchShortcutKey {
                //Delay needed to work because app is launching..
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.appCoordinator.launchUniversalScanner()
                }
            }
        } catch {

        }
        protectionCoordinator.didFinishLaunchingWithOptions()

        return true
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if shortcutItem.type == Constants.launchShortcutKey {
            appCoordinator.launchUniversalScanner()
        }
        completionHandler(true)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        protectionCoordinator.applicationWillResignActive()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        protectionCoordinator.applicationDidBecomeActive()
        appCoordinator.handleUniversalLinkInPasteboard()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        protectionCoordinator.applicationDidEnterBackground()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        protectionCoordinator.applicationWillEnterForeground()
    }

    func application(_ application: UIApplication, shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplication.ExtensionPointIdentifier) -> Bool {
        if extensionPointIdentifier == .keyboard {
            return false
        }
        return true
    }

    // URI scheme links and AirDrop
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return handleUniversalLink(url: url, source: .customUrlScheme)
    }

    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        let hasHandledIntent = appCoordinator.handleIntent(userActivity: userActivity)
        if hasHandledIntent {
            return true
        }

        var handled = false
        if let url = userActivity.webpageURL {
            handled = handleUniversalLink(url: url, source: .deeplink)
        }
        //TODO: if we handle other types of URLs, check if handled==false, then we pass the url to another handlers
        return handled
    } 

    //TODO Handle SNS errors
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        //no op
    }

    private func handleUniversalLink(url: URL, source: UrlSource) -> Bool {
        let handled = appCoordinator.handleUniversalLink(url: url, source: source)
        return handled
    }
}
