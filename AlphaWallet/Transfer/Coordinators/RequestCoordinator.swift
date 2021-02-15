// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol RequestCoordinatorDelegate: class {
    func didCancel(in coordinator: RequestCoordinator)
}

class RequestCoordinator: Coordinator {
    private let account: Wallet

    private lazy var requestViewController: RequestViewController = {
        let viewModel: RequestViewModel = .init(account: account)
        let controller = RequestViewController(viewModel: viewModel)
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(self, selector: #selector(dismiss))

        return controller
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: RequestCoordinatorDelegate?

    init(navigationController: UINavigationController = UINavigationController(), account: Wallet) {
        self.navigationController = navigationController
        self.navigationController.setNavigationBarHidden(false, animated: true)

        self.account = account
    }

    func start() {
        navigationController.pushViewController(requestViewController, animated: true)
    }

    @objc func dismiss() {
        delegate?.didCancel(in: self)
    }
}
