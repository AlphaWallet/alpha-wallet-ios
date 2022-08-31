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
    var coordinators: [Coordinator] = []
    weak var delegate: ConsoleCoordinatorDelegate?

    private lazy var consoleViewController: ConsoleViewController = {
        let vc = ConsoleViewController()
        vc.hidesBottomBarWhenPushed = true
        //TODO console just show the list of files at the moment
        let bad = assetDefinitionStore.listOfBadTokenScriptFiles.map { "\($0) is invalid" }
        let conflictsInOfficialSource = assetDefinitionStore.conflictingTokenScriptFileNames.official.map { "[Repo] \($0) has a conflict" }
        let conflictsInOverrides = assetDefinitionStore.conflictingTokenScriptFileNames.overrides.map { "[Overrides] \($0) has a conflict" }
        let conflicts = conflictsInOfficialSource + conflictsInOverrides
        vc.configure(messages: bad + conflicts)
        vc.delegate = self
        return vc
    }()

    init(assetDefinitionStore: AssetDefinitionStore, navigationController: UINavigationController) {
        self.assetDefinitionStore = assetDefinitionStore
        self.navigationController = navigationController
    }

    func start() {
        consoleViewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(consoleViewController, animated: true)
    }

    @objc private func dismissConsole(_ sender: UIBarButtonItem) {
        didClose(in: consoleViewController)
    }
}

extension ConsoleCoordinator: ConsoleViewControllerDelegate {

    func didClose(in viewController: ConsoleViewController) {
        delegate?.didCancel(in: self)
    }
}
