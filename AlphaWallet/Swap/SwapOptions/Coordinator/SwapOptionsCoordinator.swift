//
//  SwapOptionsCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.03.2022.
//

import UIKit
import FloatingPanel
import Combine
import AlphaWalletFoundation

protocol SwapOptionsCoordinatorDelegate: class {
    func didClose(in coordinator: SwapOptionsCoordinator)
}

final class SwapOptionsCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private lazy var rootViewController: SwapOptionsViewController = {
        let viewModel = SwapOptionsViewModel(configurator: configurator)
        let viewController = SwapOptionsViewController(viewModel: viewModel)
        viewController.delegate = self
        return viewController
    }()
    private let configurator: SwapOptionsConfigurator

    var coordinators: [Coordinator] = []
    weak var delegate: SwapOptionsCoordinatorDelegate?

    init(navigationController: UINavigationController, configurator: SwapOptionsConfigurator) {
        self.configurator = configurator
        self.navigationController = navigationController
    } 

    func start() {
        let navigationController = NavigationController(rootViewController: rootViewController)
        let panel = FloatingPanelController(isPanEnabled: false)
        panel.layout = FullScreenScrollableFloatingPanelLayout()
        panel.set(contentViewController: navigationController)

        panel.shouldDismissOnBackdrop = true
        panel.delegate = self
        panel.set(contentViewController: rootViewController)

        self.navigationController.present(panel, animated: true)
    }
}

extension SwapOptionsCoordinator: FloatingPanelControllerDelegate {
    func floatingPanelDidRemove(_ fpc: FloatingPanelController) {
        delegate?.didClose(in: self)
    }
}

extension SwapOptionsCoordinator: SwapOptionsViewControllerDelegate {

    func didClose(in controller: SwapOptionsViewController) {
        navigationController.dismiss(animated: true)
        delegate?.didClose(in: self)
    }
}
