import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = UITabBarController.createExampleApp()
        window?.makeKeyAndVisible()
    }
    
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let incomingURL = userActivity.webpageURL else  {
                  return
              }
        let wcUri = incomingURL.absoluteString.deletingPrefix("https://walletconnect.com/wc?uri=")
        let client = ((window!.rootViewController as! UINavigationController).viewControllers[0] as! ResponderViewController).client
        try? client.pair(uri: wcUri)
    }
}

extension UITabBarController {
    
    static func createExampleApp() -> UINavigationController    {
        let responderController = UINavigationController(rootViewController: ResponderViewController())
        return responderController
    }
}

extension String {
    func deletingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
}
