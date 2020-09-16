// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol RequestCoordinatorDelegate: class {
    func didCancel(in coordinator: RequestCoordinator)
}

class RequestCoordinator: Coordinator {
    private let account: Wallet
    private let server: RPCServer

    private lazy var requestViewController: RequestViewController = {
        let viewModel: RequestViewModel = .init(account: account, server: server)
        let controller = RequestViewController(viewModel: viewModel)
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem.cancelBarButton(self, selector: #selector(dismiss))
        
        return controller
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: RequestCoordinatorDelegate?

    init(
        navigationController: UINavigationController = UINavigationController(),
        account: Wallet,
        server: RPCServer
    ) {
        self.navigationController = navigationController
        self.navigationController.modalPresentationStyle = .formSheet
        self.account = account
        self.server = server
    }

    func start() {
        navigationController.viewControllers = [requestViewController]
    } 

    @objc func dismiss() {
        delegate?.didCancel(in: self)
    }
}
