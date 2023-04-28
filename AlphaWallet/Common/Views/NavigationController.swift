//
//  NavigationController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.08.2022.
//

import UIKit
import AlphaWalletLogger

protocol PushNotifiable {
    func didPushViewController(animated: Bool)
}

@objc protocol PopInteractable {
    func shouldBeginPopInteraction() -> Bool
}

@objc protocol PopNotifiable {
    @objc optional func willPopViewController(animated: Bool)
    func didPopViewController(animated: Bool)
}

class NavigationController: UINavigationController, UIGestureRecognizerDelegate {
    private var isPopActionInterractive: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: animated)

        guard animated, let coordinator = transitionCoordinator else {
            DispatchQueue.main.async { [viewController] in
                guard let viewController = viewController as? PushNotifiable else { return }
                verboseLog("[NavigationController].pushViewController isCancelled: \(false), viewController: \(viewController)")
                viewController.didPushViewController(animated: animated)
            }
            return
        }

        coordinator.animate(alongsideTransition: nil) { context in
            guard !context.isCancelled else { return }
            guard let viewController = viewController as? PushNotifiable else { return }
            verboseLog("[NavigationController].pushViewController isCancelled: \(context.isCancelled), viewController: \(viewController)")
            viewController.didPushViewController(animated: animated)
        }
    }

    override func popViewController(animated: Bool) -> UIViewController? {
        let isPopActionInterractive = self.isPopActionInterractive
        self.isPopActionInterractive = false

        let viewController = super.popViewController(animated: animated)

        if let viewController = viewController as? PopNotifiable {
            viewController.willPopViewController?(animated: animated)
        }

        guard animated, let coordinator = transitionCoordinator else {
            DispatchQueue.main.async {
                guard let viewController = viewController as? PopNotifiable else { return }
                verboseLog("[NavigationController].popViewController isCancelled: \(false), viewController: \(viewController)")
                viewController.didPopViewController(animated: animated)
            }

            return viewController
        }

        if isPopActionInterractive {
            coordinator.animate(alongsideTransition: nil) { context in
                guard !context.isCancelled else { return }

                guard let viewController = viewController as? PopNotifiable else { return }
                verboseLog("[NavigationController].popViewController isCancelled: \(context.isCancelled), viewController: \(viewController)")
                viewController.didPopViewController(animated: animated)
            }
        } else {
            if let viewController = viewController as? PopNotifiable {
                verboseLog("[NavigationController].popViewController, viewController: \(viewController)")
                viewController.didPopViewController(animated: animated)
            }

            coordinator.animate(alongsideTransition: nil) { _ in
                //no-op
            }
        }

        return viewController
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        isPopActionInterractive = true
        guard viewControllers.count > 1 else { return false }
        
        if let canPreventPop = topViewController as? PopInteractable {
            return canPreventPop.shouldBeginPopInteraction()
        }

        return true
    }
}
