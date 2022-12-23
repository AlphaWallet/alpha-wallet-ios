//
//  WhereAreMyTokensCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.12.2021.
//

import UIKit
import AlphaWalletFoundation

protocol WhereAreMyTokensCoordinatorDelegate: AnyObject {
    func switchToMainnetSelected(in coordinator: WhereAreMyTokensCoordinator)
    func didClose(in coordinator: WhereAreMyTokensCoordinator)
}

class WhereAreMyTokensCoordinator: NSObject, Coordinator {
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    weak var delegate: WhereAreMyTokensCoordinatorDelegate?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        super.init()
    }

    func start() {
        let viewController = PromptViewController()
        viewController.configure(viewModel: .init(
            title: R.string.localizable.whereAreMyTokensTitle(),
            description: R.string.localizable.whereAreMyTokensDescription(),
            buttonTitle: R.string.localizable.whereAreMyTokensAction()
        ))
        viewController._delegate = self

        navigationController.present(viewController, animated: true)
    }
}

extension WhereAreMyTokensCoordinator: PromptViewControllerDelegate {

    func actionButtonTapped(inController controller: PromptViewController) {
        delegate?.switchToMainnetSelected(in: self)
    }

    func didClose(in controller: PromptViewController) {
        delegate?.didClose(in: self)
    }
}
