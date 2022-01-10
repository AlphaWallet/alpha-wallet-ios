// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

class CheckDeviceCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let jailbreakChecker: JailbreakChecker

    private lazy var alertViewController: UIAlertController = {
        let controller = UIAlertController(
            title: R.string.localizable.appDeviceJailbreakTitle(preferredLanguages: Languages.preferred()),
            message: R.string.localizable.appDeviceJailbreakDescription(preferredLanguages: Languages.preferred()),
            preferredStyle: .alert
        )
        controller.popoverPresentationController?.sourceView = navigationController.view
        controller.addAction(UIAlertAction(title: R.string.localizable.oK(preferredLanguages: Languages.preferred()), style: .default))

        return controller
    }()

    var coordinators: [Coordinator] = []

    init(
        navigationController: UINavigationController,
        jailbreakChecker: JailbreakChecker
    ) {
        self.navigationController = navigationController
        self.jailbreakChecker = jailbreakChecker
    }

    func start() {
        if jailbreakChecker.isJailbroken {
            navigationController.present(alertViewController, animated: true, completion: nil)
        }
    }
}
