// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

protocol ConsoleCoordinatorDelegate: AnyObject {
    func didCancel(in coordinator: ConsoleCoordinator)
}

class ConsoleCoordinator: Coordinator {
    private let assetDefinitionStore: AssetDefinitionStore
    private let navigationController: UINavigationController
    private lazy var rootViewController: ConsoleViewController = {
        let viewModel = ConsoleViewModel(assetDefinitionStore: assetDefinitionStore)
        let viewController = ConsoleViewController(viewModel: viewModel)
        viewController.delegate = self

        return viewController
    }()

    var coordinators: [Coordinator] = []
    weak var delegate: ConsoleCoordinatorDelegate?

    init(assetDefinitionStore: AssetDefinitionStore, navigationController: UINavigationController) {
        self.assetDefinitionStore = assetDefinitionStore
        self.navigationController = navigationController
    }

    func start() {
        rootViewController.hidesBottomBarWhenPushed = true
        rootViewController.navigationItem.largeTitleDisplayMode = .never
        
        navigationController.pushViewController(rootViewController, animated: true)
    }
}

extension ConsoleCoordinator: ConsoleViewControllerDelegate {

    func didClose(in viewController: ConsoleViewController) {
        delegate?.didCancel(in: self)
    }
}
