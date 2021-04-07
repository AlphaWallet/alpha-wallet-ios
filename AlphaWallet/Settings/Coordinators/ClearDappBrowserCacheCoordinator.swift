// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import WebKit

class ClearDappBrowserCacheCoordinator: Coordinator {
    private let viewController: UIViewController
    private let analyticsCoordinator: AnalyticsCoordinator

    var coordinators: [Coordinator] = []

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
                    guard choice == 0 else { return }
                    self.logUse()
                    WKWebView.clearCache()
                })
    }
}

// MARK: Analytics
extension ClearDappBrowserCacheCoordinator {
    private func logUse() {
        analyticsCoordinator.log(action: Analytics.Action.clearBrowserCache)
    }
}