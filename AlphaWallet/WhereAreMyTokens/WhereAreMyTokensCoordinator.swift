//
//  WhereAreMyTokensCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.12.2021.
//

import UIKit

protocol WhereAreMyTokensCoordinatorDelegate: class {
    func switchToMainnetSelected(in coordinator: WhereAreMyTokensCoordinator)
    func didDismiss(in coordinator: WhereAreMyTokensCoordinator)
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
            title: R.string.localizable.whereAreMyTokensTitle(preferredLanguages: Languages.preferred()),
            description: R.string.localizable.whereAreMyTokensDescription(preferredLanguages: Languages.preferred()),
            buttonTitle: R.string.localizable.whereAreMyTokensAction(preferredLanguages: Languages.preferred())
        ))
        viewController._delegate = self

        navigationController.present(viewController, animated: true)
    }
}

extension WhereAreMyTokensCoordinator: PromptViewControllerDelegate {

    func actionButtonTapped(inController controller: PromptViewController) {
        delegate?.switchToMainnetSelected(in: self)
    }

    func controllerDismiss(_ controller: PromptViewController) {
        delegate?.didDismiss(in: self)
    }
}
