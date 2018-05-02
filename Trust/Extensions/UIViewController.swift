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
        alertController.popoverPresentationController?.sourceView = self.view
        alertController.addAction(UIAlertAction(title: R.string.localizable.oK(), style: UIAlertActionStyle.default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }

    func displayError(error: Error) {
        let alertController = UIAlertController(title: error.prettyError, message: "", preferredStyle: UIAlertControllerStyle.alert)
        alertController.popoverPresentationController?.sourceView = self.view
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
        alertController.popoverPresentationController?.sourceView = self.view
        alertController.addAction(UIAlertAction(title: okTitle, style: okStyle, handler: { _ in
            completion(.success(()))
        }))
        alertController.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: { _ in
            completion(.failure(ConfirmationError.cancel))
        }))
        self.present(alertController, animated: true, completion: nil)
    }

    func displayLoading(
        text: String = R.string.localizable.loadingDots(),
        animated: Bool = true
    ) {
        let hud = MBProgressHUD.showAdded(to: self.view, animated: animated)
        hud.label.text = text
    }

    func hideLoading(animated: Bool = true) {
        MBProgressHUD.hide(for: view, animated: animated)
    }

    func openURL(_ url: URL) {
        let controller = SFSafariViewController(url: url)
        // Don't attempt to change tint colors for SFSafariViewController. It doesn't well correctly especially because the controller sets more than 1 color for the title
        present(controller, animated: true, completion: nil)
    }

    public var isVisible: Bool {
        if isViewLoaded {
            return view.window != nil
        }
        return false
    }

    public var isTopViewController: Bool {
        if self.navigationController != nil {
            return self.navigationController?.visibleViewController === self
        } else if self.tabBarController != nil {
            return self.tabBarController?.selectedViewController == self && self.presentedViewController == nil
        }
        return self.presentedViewController == nil && self.isVisible
    }

}
