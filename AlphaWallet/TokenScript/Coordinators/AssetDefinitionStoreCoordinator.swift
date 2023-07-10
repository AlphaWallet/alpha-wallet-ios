// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation

protocol AssetDefinitionStoreCoordinatorDelegate: AnyObject {
    func didClose(in coordinator: AssetDefinitionStoreCoordinator)
}

class AssetDefinitionStoreCoordinator: Coordinator {
    private let tokenScriptOverridesFileManager: TokenScriptOverridesFileManager
    private let navigationController: UINavigationController
    private lazy var rootViewController: AssetDefinitionsOverridesViewController = {
        let viewModel = AssetDefinitionsOverridesViewModel(tokenScriptOverridesFileManager: tokenScriptOverridesFileManager, fileExtension: XMLHandler.fileExtension)
        let viewController = AssetDefinitionsOverridesViewController(viewModel: viewModel)
        viewController.delegate = self
        viewController.hidesBottomBarWhenPushed = true
        viewController.navigationItem.largeTitleDisplayMode = .never

        return viewController
    }()

    weak var delegate: AssetDefinitionStoreCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    init(tokenScriptOverridesFileManager: TokenScriptOverridesFileManager, navigationController: UINavigationController) {
        self.tokenScriptOverridesFileManager = tokenScriptOverridesFileManager
        self.navigationController = navigationController
    }

    func start() {
        navigationController.pushViewController(rootViewController, animated: true)
    }
}

extension AssetDefinitionStoreCoordinator: AssetDefinitionsOverridesViewControllerDelegate {
    func didClose(in viewController: AssetDefinitionsOverridesViewController) {
        delegate?.didClose(in: self)
    }

    func didTapShare(file: URL, in viewController: AssetDefinitionsOverridesViewController) {
        viewController.showShareActivity(fromSource: .view(viewController.view), with: [file])
    }
}
