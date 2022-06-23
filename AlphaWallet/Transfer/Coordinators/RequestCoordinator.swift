// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol RequestCoordinatorDelegate: AnyObject {
    func didCancel(in coordinator: RequestCoordinator)
}

class RequestCoordinator: Coordinator {
    private let account: Wallet
    private let domainResolutionService: DomainResolutionServiceType

    private lazy var requestViewController: RequestViewController = {
        let viewModel: RequestViewModel = .init(account: account)
        let controller = RequestViewController(viewModel: viewModel, domainResolutionService: domainResolutionService)
        controller.navigationItem.largeTitleDisplayMode = .never
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(self, selector: #selector(dismiss))

        return controller
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: RequestCoordinatorDelegate?

    init(navigationController: UINavigationController, account: Wallet, domainResolutionService: DomainResolutionServiceType) {
        self.navigationController = navigationController
        self.account = account
        self.domainResolutionService = domainResolutionService
    }

    func start() {
        requestViewController.hidesBottomBarWhenPushed = true
        navigationController.pushViewController(requestViewController, animated: true)
    }

    @objc func dismiss() {
        delegate?.didCancel(in: self)
    }
}
