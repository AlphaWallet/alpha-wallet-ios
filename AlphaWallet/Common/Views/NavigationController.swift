//
//  NavigationController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.08.2022.
//

import UIKit
import AlphaWalletFoundation

protocol PushNotifiable {
    func didPushViewController(animated: Bool)
}

protocol PopNotifiable {
    func didPopViewController(animated: Bool)
}

class NavigationController: UINavigationController {
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
        let viewController = super.popViewController(animated: animated)

        guard animated, let coordinator = transitionCoordinator else {
            DispatchQueue.main.async {
                guard let viewController = viewController as? PopNotifiable else { return }
                verboseLog("[NavigationController].popViewController isCancelled: \(false), viewController: \(viewController)")
                viewController.didPopViewController(animated: animated)
            }
            return viewController
        }

        coordinator.animate(alongsideTransition: nil) { context in
            guard !context.isCancelled else { return }

            guard let viewController = viewController as? PopNotifiable else { return }
            verboseLog("[NavigationController].popViewController isCancelled: \(context.isCancelled), viewController: \(viewController)")
            viewController.didPopViewController(animated: animated)
        }

        return viewController
    }
}
