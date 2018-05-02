// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

class CheckDeviceCoordinator: Coordinator {
    var coordinators: [Coordinator] = []

    let navigationController: UINavigationController

    let jailbreakChecker: JailbreakChecker

    lazy var alertViewController: UIAlertController = {
        let controller = UIAlertController(
            title: R.string.localizable.appDeviceJailbreakTitle(),
            message: R.string.localizable.appDeviceJailbreakDescription(),
            preferredStyle: UIAlertControllerStyle.alert
        )
        controller.popoverPresentationController?.sourceView = navigationController.view
        controller.addAction(UIAlertAction(title: R.string.localizable.oK(), style: .default))

        return controller
    }()

    init(
        navigationController: UINavigationController,
        jailbreakChecker: JailbreakChecker
    ) {
        self.navigationController = navigationController
        self.jailbreakChecker = jailbreakChecker
    }

    func start() {
        if jailbreakChecker.isJailbroken() {
            navigationController.present(alertViewController, animated: true, completion: nil)
        }
    }
}
