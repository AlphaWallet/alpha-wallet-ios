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
        let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alertController.popoverPresentationController?.sourceView = view
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(), style: .default, handler: nil))
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
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.popoverPresentationController?.sourceView = view
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(), style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }

    func confirm(
        title: String? = .none,
        message: String? = .none,
        okTitle: String = R.string.localizable.oK(),
        okStyle: UIAlertAction.Style = .default,
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
