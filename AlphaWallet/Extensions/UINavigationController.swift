// Copyright SIX DAY LLC. All rights reserved.

import UIKit

extension UINavigationController {
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
