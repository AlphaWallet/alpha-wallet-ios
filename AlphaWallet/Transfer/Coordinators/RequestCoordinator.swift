// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import AlphaWalletFoundation

protocol RequestCoordinatorDelegate: AnyObject {
    func didCancel(in coordinator: RequestCoordinator)
}

class RequestCoordinator: Coordinator {
    private let account: Wallet
    private let domainResolutionService: DomainNameResolutionServiceType

    private lazy var requestViewController: RequestViewController = {
        let viewModel = RequestViewModel(account: account, domainResolutionService: domainResolutionService)
        let controller = RequestViewController(viewModel: viewModel)
        controller.navigationItem.largeTitleDisplayMode = .never
        controller.hidesBottomBarWhenPushed = true
        controller.delegate = self

        return controller
    }()

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: RequestCoordinatorDelegate?

    init(navigationController: UINavigationController, account: Wallet, domainResolutionService: DomainNameResolutionServiceType) {
        self.navigationController = navigationController
        self.account = account
        self.domainResolutionService = domainResolutionService
    }

    func start() {
        navigationController.pushViewController(requestViewController, animated: true)
    }

}

extension RequestCoordinator: RequestViewControllerDelegate {
    func didClose(in viewController: RequestViewController) {
        delegate?.didCancel(in: self)
    }
}
