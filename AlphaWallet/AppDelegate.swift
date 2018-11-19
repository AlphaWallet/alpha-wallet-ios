// Copyright SIX DAY LLC. All rights reserved.
import UIKit
import RealmSwift
import AWSSNS
//import AWSCognito
import AWSCore
import UserNotifications
import TrustKeystore
import web3swift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    var window: UIWindow?
    private var appCoordinator: AppCoordinator!
    private let SNSPlatformApplicationArn = "arn:aws:sns:us-west-2:400248756644:app/APNS/AlphaWallet-iOS"
    private let SNSPlatformApplicationArnSANDBOX = "arn:aws:sns:us-west-2:400248756644:app/APNS_SANDBOX/AlphaWallet-testing"
    private let identityPoolId = "us-west-2:42f7f376-9a3f-412e-8c15-703b5d50b4e2"
    private let SNSSecurityTopicEndpoint = "arn:aws:sns:us-west-2:400248756644:security"
    //This is separate coordinator for the protection of the sensitive information.
    private lazy var protectionCoordinator: ProtectionCoordinator = {
        return ProtectionCoordinator()
    }()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print(Realm.Configuration().fileURL!)
        window = UIWindow(frame: UIScreen.main.bounds)
        do {
            let keystore = try EtherKeystore()
            appCoordinator = AppCoordinator(window: window!, keystore: keystore)
            appCoordinator.start()
        } catch {
            print("EtherKeystore init issue.")
        }
        //Status bar hidden at launch so launch screen is not distorted when call/tether bar is activated in phones without a notch, like iPhone 8 and earlier
        application.isStatusBarHidden = false
        protectionCoordinator.didFinishLaunchingWithOptions()

        return true
    }

    private func cognitoRegistration() {
        // Override point for customization after application launch.
        /// Setup AWS Cognito credentials
        // Initialize the Amazon Cognito credentials provider
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType: .USWest2,
                identityPoolId: identityPoolId)
        let configuration = AWSServiceConfiguration(region: .USWest2, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        let defaultServiceConfiguration = AWSServiceConfiguration(
                region: AWSRegionType.USWest2, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = defaultServiceConfiguration
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

    func application(_ application: UIApplication, shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplication.ExtensionPointIdentifier) -> Bool {
        if extensionPointIdentifier == .keyboard {
            return false
        }
        return true
    }

    // Respond to URI scheme links
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        let _ = appCoordinator.handleOpen(url: url)
        return true
    }

    // Respond to Universal Links
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        var handled = false
        if let url = userActivity.webpageURL {
            handled = handleUniversalLink(url: url)
        }
        //TODO: if we handle other types of URLs, check if handled==false, then we pass the url to another handlers
        return handled
    }
    
    // Respond to amazon SNS registration
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        /// Attach the device token to the user defaults
        var token = ""
        for i in 0..<deviceToken.count {
            let tokenInfo = String(format: "%02.2hhx", arguments: [deviceToken[i]])
            token.append(tokenInfo)
        }
        print(token)
        UserDefaults.standard.set(token, forKey: "deviceTokenForSNS")
        /// Create a platform endpoint. In this case, the endpoint is a
        /// device endpoint ARN
        cognitoRegistration()
        let sns = AWSSNS.default()
        let request = AWSSNSCreatePlatformEndpointInput()
        request?.token = token
        #if DEBUG
            request?.platformApplicationArn = SNSPlatformApplicationArnSANDBOX
        #else
            request?.platformApplicationArn = SNSPlatformApplicationArn
        #endif

        sns.createPlatformEndpoint(request!).continueWith(executor: AWSExecutor.mainThread(), block: { (task: AWSTask!) -> AnyObject? in
            if task.error != nil {
                print("Error: \(String(describing: task.error))")
            } else {
                let createEndpointResponse = task.result! as AWSSNSCreateEndpointResponse
                if let endpointArnForSNS = createEndpointResponse.endpointArn {
                    print("endpointArn: \(endpointArnForSNS)")
                    UserDefaults.standard.set(endpointArnForSNS, forKey: "endpointArnForSNS")
                    //every user should subscribe to the security topic
                    self.subscribeToTopicSNS(token: token, topicEndpoint: self.SNSSecurityTopicEndpoint)
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        //TODO subscribe to version topic when created
                    }
                }
            }
            return nil
        })
    }

    func subscribeToTopicSNS(token: String, topicEndpoint: String) {
        let sns = AWSSNS.default()
        guard let endpointRequest = AWSSNSCreatePlatformEndpointInput() else { return }
        #if DEBUG
            endpointRequest.platformApplicationArn = SNSPlatformApplicationArnSANDBOX
        #else
            endpointRequest.platformApplicationArn = SNSPlatformApplicationArn
        #endif
        endpointRequest.token = token

        sns.createPlatformEndpoint(endpointRequest).continueWith() { task in
            guard let response: AWSSNSCreateEndpointResponse = task.result else { return nil }
            guard let subscribeRequest = AWSSNSSubscribeInput() else { return nil }
            subscribeRequest.endpoint = response.endpointArn
            subscribeRequest.protocols = "application"
            subscribeRequest.topicArn = topicEndpoint
            return sns.subscribe(subscribeRequest)
        }
    }

    //TODO Handle SNS errors
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error.localizedDescription)
    }

    @discardableResult private func handleUniversalLink(url: URL) -> Bool {
        let handled = appCoordinator.handleUniversalLink(url: url)
        return handled
    }
}
