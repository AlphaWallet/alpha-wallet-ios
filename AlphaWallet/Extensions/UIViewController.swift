// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import Result
import MBProgressHUD
import SafariServices

enum ConfirmationError: LocalizedError {
    case cancel
}

extension UIViewController {
    func displaySuccess(title: String? = .none, message: String? = .none) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alertController.popoverPresentationController?.sourceView = view
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(), style: UIAlertActionStyle.default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }

    func displayError(title: String = "", error: Error) {
        var title = title
        let message: String
        if title.isEmpty {
            title = error.prettyError
            message = ""
        } else {
            message = error.prettyError
        }
        let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alertController.popoverPresentationController?.sourceView = view
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(), style: UIAlertActionStyle.default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }

    func confirm(
        title: String? = .none,
        message: String? = .none,
        okTitle: String = R.string.localizable.oK(),
        okStyle: UIAlertActionStyle = .default,
        completion: @escaping (Result<Void, ConfirmationError>) -> Void
    ) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.popoverPresentationController?.sourceView = view
        alertController.addAction(UIAlertAction(title: okTitle, style: okStyle, handler: { _ in
            completion(.success(()))
        }))
        alertController.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: { _ in
            completion(.failure(ConfirmationError.cancel))
        }))
        present(alertController, animated: true, completion: nil)
    }

    func displayLoading(
        text: String = R.string.localizable.loadingDots(),
        animated: Bool = true
    ) {
        let hud = MBProgressHUD.showAdded(to: view, animated: animated)
        hud.label.text = text
    }

    func hideLoading(animated: Bool = true) {
        MBProgressHUD.hide(for: view, animated: animated)
    }

    public var isVisible: Bool {
        if isViewLoaded {
            return view.window != nil
        }
        return false
    }

    public var isTopViewController: Bool {
        if navigationController != nil {
            return navigationController?.visibleViewController === self
        } else if tabBarController != nil {
            return tabBarController?.selectedViewController == self && presentedViewController == nil
        }
        return presentedViewController == nil && isVisible
    }

    func add(asChildViewController viewController: UIViewController) {
        addChildViewController(viewController)
        view.addSubview(viewController.view)
        viewController.view.frame = view.bounds
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        viewController.didMove(toParentViewController: self)
    }

    func remove(asChildViewController viewController: UIViewController) {
        viewController.willMove(toParentViewController: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParentViewController()
    }

    func showShareActivity(from sender: UIView, with items: [Any], completion: (() -> Swift.Void)? = nil) {
        let activityViewController = UIActivityViewController.make(items: items)
        activityViewController.popoverPresentationController?.sourceView = sender
        activityViewController.popoverPresentationController?.sourceRect = sender.centerRect
        present(activityViewController, animated: true, completion: completion)
    }
}
