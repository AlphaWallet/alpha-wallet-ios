// Copyright SIX DAY LLC. All rights reserved.

import UIKit

extension UINavigationController {

    static func withOverridenBarAppearence(appearence: UINavigationBarAppearance = .defaultAppearence) -> UINavigationController {
        let instance = NavigationController()
        instance.navigationBar.compactAppearance = appearence
        instance.navigationBar.standardAppearance = appearence
        instance.navigationBar.scrollEdgeAppearance = appearence

        return instance
    }
    
    /// Removes all instances of view controller from navigation stack of type `T` skipping instance `avoidToRemove`
    func removeViewControllerOfSameType<T>(except avoidToRemove: T) where T: UIViewController {
        viewControllers = viewControllers.filter { !($0 is T) || $0 == avoidToRemove }
    }

    func configureForLargeTitles() {
        navigationBar.prefersLargeTitles = true
        //When we enable large titles,
        //1. we can't get `UINavigationBar.appearance().setBackgroundImage(UIImage(color: Colors.appBackground), for: .default)` to work anymore, needing to replace it with: `UINavigationBar.appearance().barTintColor = Colors.appBackground`.
        //2. Without the former, we need to clear `isTranslucent` in order for view controllers that do not embed scroll views to clip off content at the top (unless we offset ourselves).
        //3. And when we clear `isTranslucent`, we need to set the navigationController's background ourselves, otherwise when pushing a view controller, the navigationController will show as black
        navigationBar.isTranslucent = false
        view.backgroundColor = Colors.appBackground
    }
    
    //Remove after iOS 11.2 will patch this bug.
    func applyTintAdjustment() {
        navigationBar.tintAdjustmentMode = .normal
        navigationBar.tintAdjustmentMode = .automatic
    }

    public func pushViewController(_ viewController: UIViewController, animated: Bool, completion: @escaping () -> Void) {
        pushViewController(viewController, animated: animated)

        guard animated, let coordinator = transitionCoordinator else {
            DispatchQueue.main.async {
                completion()
            }
            return
        }

        coordinator.animate(alongsideTransition: nil) { _ in
            completion()
        }
    }

    func popViewController(animated: Bool, completion: @escaping () -> Void) {
        popViewController(animated: animated)

        guard animated, let coordinator = transitionCoordinator else {
            DispatchQueue.main.async {
                completion()
            }
            return
        }

        coordinator.animate(alongsideTransition: nil) { _ in
            completion()
        }
    }

}
