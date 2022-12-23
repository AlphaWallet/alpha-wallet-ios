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

protocol SwapOptionsCoordinatorDelegate: AnyObject {
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
        panel.surfaceView.contentPadding = .init(top: 20, left: 0, bottom: 0, right: 0)
        panel.shouldDismissOnBackdrop = true
        panel.delegate = self

        self.navigationController.present(panel, animated: true)
    }
}

extension SwapOptionsCoordinator: FloatingPanelControllerDelegate {
    func floatingPanelDidRemove(_ fpc: FloatingPanelController) {
        delegate?.didClose(in: self)
    }
}

extension SwapOptionsCoordinator: SwapOptionsViewControllerDelegate {
    func choseSwapToolSelected(in controller: SwapOptionsViewController) {
        guard let navigationController = controller.navigationController else { return }

        let viewModel = SelectSwapToolViewModel(storage: configurator.tokenSwapper.storage)
        let viewController = SelectSwapToolViewController(viewModel: viewModel)
        navigationController.pushViewController(viewController, animated: true)
    }

    func didClose(in controller: SwapOptionsViewController) {
        navigationController.dismiss(animated: true)
        delegate?.didClose(in: self)
    }
}
