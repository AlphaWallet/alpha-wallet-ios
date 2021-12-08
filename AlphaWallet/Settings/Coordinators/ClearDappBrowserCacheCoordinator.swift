// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import WebKit

protocol ClearDappBrowserCacheCoordinatorDelegate: AnyObject {
    func done(in coordinator: ClearDappBrowserCacheCoordinator)
    func didCancel(in coordinator: ClearDappBrowserCacheCoordinator)
}

class ClearDappBrowserCacheCoordinator: Coordinator {
    private let viewController: UIViewController
    private let analyticsCoordinator: AnalyticsCoordinator

    var coordinators: [Coordinator] = []
    weak var delegate: ClearDappBrowserCacheCoordinatorDelegate?

    init(inViewController viewController: UIViewController, analyticsCoordinator: AnalyticsCoordinator) {
        self.viewController = viewController
        self.analyticsCoordinator = analyticsCoordinator
    }

    func start() {
        UIAlertController.alert(title: "\(R.string.localizable.aSettingsContentsClearDappBrowserCache())?",
                message: nil,
                alertButtonTitles: [R.string.localizable.oK(), R.string.localizable.cancel()],
                alertButtonStyles: [.destructive, .cancel],
                viewController: viewController,
                completion: { choice in
                    guard choice == 0 else {
                        self.delegate?.didCancel(in: self)
                        return
                    }
                    self.logUse()
                    WKWebView.clearCache()
                    self.delegate?.done(in: self)
                })
    }
}

// MARK: Analytics
extension ClearDappBrowserCacheCoordinator {
    private func logUse() {
        analyticsCoordinator.log(action: Analytics.Action.clearBrowserCache)
    }
}