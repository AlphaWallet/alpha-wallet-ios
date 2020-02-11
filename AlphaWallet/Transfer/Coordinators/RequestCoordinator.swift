// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol RequestCoordinatorDelegate: class {
    func didCancel(in coordinator: RequestCoordinator)
}

class RequestCoordinator: Coordinator {
    private let session: WalletSession

    private lazy var viewModel: RequestViewModel = {
        return .init(account: session.account, server: session.server)
    }()

    private lazy var requestViewController: RequestViewController = {
        return makeRequestViewController()
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: RequestCoordinatorDelegate?

    init(
        navigationController: UINavigationController = UINavigationController(),
        session: WalletSession
    ) {
        self.navigationController = navigationController
        self.navigationController.modalPresentationStyle = .formSheet
        self.session = session
    }

    func start() {
        navigationController.viewControllers = [requestViewController]
    }

    func makeRequestViewController() -> RequestViewController {
        let controller = RequestViewController(viewModel: viewModel)
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(dismiss))
        return controller
    }

    @objc func dismiss() {
        delegate?.didCancel(in: self)
    }
}
