// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation
import AlphaWalletTokenScript

protocol TokenScriptOverridesCoordinatorDelegate: AnyObject {
    func didClose(in coordinator: TokenScriptOverridesCoordinator)
}

class TokenScriptOverridesCoordinator: Coordinator {
    private let tokenScriptOverridesFileManager: TokenScriptOverridesFileManager
    private let navigationController: UINavigationController
    private lazy var rootViewController: TokenScriptOverridesViewController = {
        let viewModel = TokenScriptOverridesViewModel(tokenScriptOverridesFileManager: tokenScriptOverridesFileManager, fileExtension: XMLHandler.fileExtension)
        let viewController = TokenScriptOverridesViewController(viewModel: viewModel)
        viewController.delegate = self
        viewController.hidesBottomBarWhenPushed = true
        viewController.navigationItem.largeTitleDisplayMode = .never

        return viewController
    }()

    weak var delegate: TokenScriptOverridesCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    init(tokenScriptOverridesFileManager: TokenScriptOverridesFileManager, navigationController: UINavigationController) {
        self.tokenScriptOverridesFileManager = tokenScriptOverridesFileManager
        self.navigationController = navigationController
    }

    func start() {
        navigationController.pushViewController(rootViewController, animated: true)
    }
}

extension TokenScriptOverridesCoordinator: TokenScriptOverridesViewControllerDelegate {
    func didClose(in viewController: TokenScriptOverridesViewController) {
        delegate?.didClose(in: self)
    }

    func didTapShare(file: URL, in viewController: TokenScriptOverridesViewController) {
        viewController.showShareActivity(fromSource: .view(viewController.view), with: [file])
    }
}
