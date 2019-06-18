// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import WebKit

class ClearDappBrowserCacheCoordinator: Coordinator {
    private let viewController: UIViewController

    var coordinators: [Coordinator] = []

    init(inViewController viewController: UIViewController) {
        self.viewController = viewController
    }

    func start() {
        UIAlertController.alert(title: "\(R.string.localizable.aSettingsContentsClearDappBrowserCache())?",
                message: nil,
                alertButtonTitles: [R.string.localizable.oK(), R.string.localizable.cancel()],
                alertButtonStyles: [.destructive, .cancel],
                viewController: viewController,
                completion: { [weak self] choice in
                    guard let strongSelf = self else { return }
                    guard choice == 0 else { return }
                    WKWebView.clearCache()
                })
    }
}
