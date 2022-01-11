// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import Result
import MBProgressHUD
import SafariServices

enum ConfirmationError: LocalizedError {
    case cancel
}

extension UIView {
    func showCopiedToClipboard(title: String, feedbackType: NotificationFeedbackType? = .success) {
        let hud = MBProgressHUD.showAdded(to: self, animated: true)
        hud.mode = .text
        hud.label.text = title
        hud.hide(animated: true, afterDelay: 1.5)

        if let feedback = feedbackType {
            UINotificationFeedbackGenerator.show(feedbackType: feedback)
        }
    }
}

extension UIViewController {
    @discardableResult func displaySuccess(title: String? = .none, message: String? = .none) -> UIViewController {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alertController.popoverPresentationController?.sourceView = view
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(preferredLanguages: Languages.preferred()), style: .default, handler: nil))
        present(alertController, animated: true)

        return alertController
    }

    func displayError(message: String, completion: @escaping () -> Void = {}) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.popoverPresentationController?.sourceView = view
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(preferredLanguages: Languages.preferred()), style: .default) { _ in
            completion()
        })

        present(alertController, animated: true)
    }

    @discardableResult func displayError(title: String = "", error: Error) -> UIViewController {
        var title = title
        let message: String
        if title.isEmpty {
            title = error.prettyError
            message = ""
        } else {
            message = error.prettyError
        }
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.popoverPresentationController?.sourceView = view
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(preferredLanguages: Languages.preferred()), style: .default, handler: nil))
        present(alertController, animated: true)

        return alertController
    }

    func confirm(
        title: String? = .none,
        message: String? = .none,
        okTitle: String = R.string.localizable.oK(preferredLanguages: Languages.preferred()),
        okStyle: UIAlertAction.Style = .default,
        completion: @escaping (Result<Void, ConfirmationError>) -> Void
    ) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.popoverPresentationController?.sourceView = view
        alertController.addAction(UIAlertAction(title: okTitle, style: okStyle, handler: { _ in
            completion(.success(()))
        }))
        alertController.addAction(UIAlertAction(title: R.string.localizable.cancel(preferredLanguages: Languages.preferred()), style: .cancel, handler: { _ in
            completion(.failure(ConfirmationError.cancel))
        }))
        present(alertController, animated: true, completion: nil)
    }

    func displayLoading(
        text: String = R.string.localizable.loadingDots(preferredLanguages: Languages.preferred()),
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
        if navigationController != nil && navigationController?.tabBarController != nil {
            return (tabBarController?.selectedViewController as? UINavigationController)?.visibleViewController == self
        } else if navigationController != nil {
            return navigationController?.visibleViewController === self
        } else if tabBarController != nil {
            return tabBarController?.selectedViewController == self && presentedViewController == nil
        }
        return presentedViewController == nil && isVisible
    }

    func add(asChildViewController viewController: UIViewController) {
        addChild(viewController)
        view.addSubview(viewController.view)
        viewController.view.frame = view.bounds
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        viewController.didMove(toParent: self)
    }

    func remove(asChildViewController viewController: UIViewController) {
        viewController.willMove(toParent: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
    }

    func showShareActivity(fromSource source: PopoverPresentationControllerSource, with items: [Any], completion: (() -> Swift.Void)? = nil) {
        let activityViewController = UIActivityViewController.make(items: items)
        switch source {
        case .barButtonItem(let barButtonItem):
            activityViewController.popoverPresentationController?.barButtonItem = barButtonItem
        case .view(let view):
            activityViewController.popoverPresentationController?.sourceView = view
            //Cannot use view.rect because it might be too small (e.g. it's a button)
            activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 500, height: 500)
        }
        present(activityViewController, animated: true, completion: completion)
    }

    //TODO remove all callers for this function. This is added for a scoped down migration to Xcode 11.x (building for iOS 13), to make sure that all presented screens remain fullscreen. We should decide to either show them by presenting as (A) fullscreen (B) card or (C) push onto a navigation controller
    //Shouldn't be called for UIActivityViewController and UIAlertController
    func makePresentationFullScreenForiOS13Migration() {
        modalPresentationStyle = .fullScreen
    }
}
