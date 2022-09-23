//
//  WalletPupupCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.03.2022.
//

import UIKit
import AlphaWalletFoundation

protocol WalletPupupCoordinatorDelegate: class {
    func didSelect(action: PupupAction, in coordinator: WalletPupupCoordinator)
    func didClose(in coordinator: WalletPupupCoordinator)
}

class WalletPupupCoordinator: Coordinator {
    private let navigationController: UINavigationController
    
    var coordinators: [Coordinator] = []
    weak var delegate: WalletPupupCoordinatorDelegate?

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    private lazy var rootViewController: WalletPupupViewController = {
        let viewController = WalletPupupViewController()
        viewController.delegate = self
        return viewController
    }()

    func start() {
        let panel = FloatingPanelController(isPanEnabled: true)
        panel.layout = SelfSizingPanelLayout()
        panel.set(contentViewController: rootViewController)
        panel.shouldDismissOnBackdrop = true

        navigationController.present(panel, animated: true)
    }
}

extension WalletPupupCoordinator: WalletPupupViewControllerDelegate {
    func didSelect(action: PupupAction, in viewController: WalletPupupViewController) {
        viewController.dismiss(animated: true) {
            self.delegate?.didSelect(action: action, in: self)
        }
    }
}
