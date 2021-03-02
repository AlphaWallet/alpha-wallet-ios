// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import RealmSwift
import PromiseKit

private struct NoContractDetailsDetected: Error {
}

protocol AddHideTokensCoordinatorDelegate: class {
    func didClose(coordinator: AddHideTokensCoordinator)
}

class AddHideTokensCoordinator: Coordinator {
    private let analyticsCoordinator: AnalyticsCoordinator
    private let navigationController: UINavigationController
    private var viewModel: AddHideTokensViewModel
    private lazy var viewController: AddHideTokensViewController = .init(
        viewModel: viewModel,
        sessions: sessions,
        assetDefinitionStore: assetDefinitionStore
    )
    private let tokenCollection: TokenCollection
    private let sessions: ServerDictionary<WalletSession>
    private let filterTokensCoordinator: FilterTokensCoordinator
    private let assetDefinitionStore: AssetDefinitionStore
    private let singleChainTokenCoordinators: [SingleChainTokenCoordinator]
    private let config: Config

    var coordinators: [Coordinator] = []
    weak var delegate: AddHideTokensCoordinatorDelegate?

    init(tokens: [TokenObject], assetDefinitionStore: AssetDefinitionStore, filterTokensCoordinator: FilterTokensCoordinator, tickers: [RPCServer: [AlphaWallet.Address: CoinTicker]], sessions: ServerDictionary<WalletSession>, analyticsCoordinator: AnalyticsCoordinator, navigationController: UINavigationController, tokenCollection: TokenCollection, config: Config, singleChainTokenCoordinators: [SingleChainTokenCoordinator]) {
        self.config = config
        self.filterTokensCoordinator = filterTokensCoordinator
        self.sessions = sessions

        self.analyticsCoordinator = analyticsCoordinator
        self.navigationController = navigationController
        self.tokenCollection = tokenCollection
        self.assetDefinitionStore = assetDefinitionStore
        self.singleChainTokenCoordinators = singleChainTokenCoordinators
        self.viewModel = AddHideTokensViewModel(
            tokens: tokens,
            tickers: tickers,
            filterTokensCoordinator: filterTokensCoordinator
        )
    }

    func start() {
        viewController.delegate = self
        navigationController.pushViewController(viewController, animated: true)
    }

    @objc func dismiss() {
        navigationController.dismiss(animated: true)
    }

    private func singleChainTokenCoordinator(forServer server: RPCServer) -> SingleChainTokenCoordinator? {
        singleChainTokenCoordinators.first { $0.isServer(server) }
    }
}

extension AddHideTokensCoordinator: NewTokenCoordinatorDelegate {

    func didClose(in coordinator: NewTokenCoordinator) {
        removeCoordinator(coordinator)
    }

    func coordinator(_ coordinator: NewTokenCoordinator, didAddToken token: TokenObject) {
        removeCoordinator(coordinator)

        viewController.add(token: token)
    }
}

extension AddHideTokensCoordinator: AddHideTokensViewControllerDelegate {

    func didChangeOrder(tokens: [TokenObject], in viewController: UIViewController) {
        guard let token = tokens.first else { return }
        guard let coordinator = singleChainTokenCoordinator(forServer: token.server) else { return }
        coordinator.updateOrderedTokens(with: tokens)
    }

    func didMark(token: TokenObject, in viewController: UIViewController, isHidden: Bool) {
        guard let coordinator = singleChainTokenCoordinator(forServer: token.server) else { return }
        coordinator.mark(token: token, isHidden: isHidden)
    }

    func didPressAddToken(in viewController: UIViewController) {
        let coordinator = NewTokenCoordinator(
            analyticsCoordinator: analyticsCoordinator,
            navigationController: navigationController,
            tokenCollection: tokenCollection,
            config: config,
            singleChainTokenCoordinators: singleChainTokenCoordinators,
            sessions: sessions
        )
        coordinator.delegate = self
        addCoordinator(coordinator)

        coordinator.start()
    }

    func didClose(viewController: AddHideTokensViewController) {
        delegate?.didClose(coordinator: self)
    }
}
