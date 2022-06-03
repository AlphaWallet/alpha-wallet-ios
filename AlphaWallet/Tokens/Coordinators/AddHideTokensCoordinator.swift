// Copyright © 2020 Stormbird PTE. LTD.

import UIKit 
import PromiseKit

private struct NoContractDetailsDetected: Error {
}

protocol AddHideTokensCoordinatorDelegate: AnyObject {
    func didClose(coordinator: AddHideTokensCoordinator)
}

class AddHideTokensCoordinator: Coordinator {
    private let analyticsCoordinator: AnalyticsCoordinator
    private let navigationController: UINavigationController
    private lazy var viewModel = AddHideTokensViewModel(tokens: tokens, tokensFilter: tokensFilter, singleChainTokenCoordinators: singleChainTokenCoordinators, config: config)
    private lazy var viewController: AddHideTokensViewController = {
        return .init(viewModel: viewModel, assetDefinitionStore: assetDefinitionStore)
    }()

    private let sessions: ServerDictionary<WalletSession>
    private let assetDefinitionStore: AssetDefinitionStore
    private let singleChainTokenCoordinators: [SingleChainTokenCoordinator]
    private let config: Config
    private var tokens: [Token]
    private let tokensFilter: TokensFilter
    var coordinators: [Coordinator] = []
    weak var delegate: AddHideTokensCoordinatorDelegate?

    init(tokens: [Token], assetDefinitionStore: AssetDefinitionStore, tokensFilter: TokensFilter, sessions: ServerDictionary<WalletSession>, analyticsCoordinator: AnalyticsCoordinator, navigationController: UINavigationController, config: Config, singleChainTokenCoordinators: [SingleChainTokenCoordinator]) {
        self.config = config
        self.sessions = sessions
        self.tokens = tokens
        self.tokensFilter = tokensFilter
        self.analyticsCoordinator = analyticsCoordinator
        self.navigationController = navigationController
        self.assetDefinitionStore = assetDefinitionStore
        self.singleChainTokenCoordinators = singleChainTokenCoordinators
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

    func coordinator(_ coordinator: NewTokenCoordinator, didAddToken token: Token) {
        removeCoordinator(coordinator)

        viewModel.add(token: token)
    }
}

extension AddHideTokensCoordinator: AddHideTokensViewControllerDelegate {

    func didChangeOrder(tokens: [Token], in viewController: UIViewController) {
        guard let token = tokens.first else { return }
        guard let coordinator = singleChainTokenCoordinator(forServer: token.server) else { return }
        coordinator.updateOrderedTokens(with: tokens)
    }

    func didMark(token: Token, in viewController: UIViewController, isHidden: Bool) {
        guard let coordinator = singleChainTokenCoordinator(forServer: token.server) else { return }
        coordinator.mark(token: token, isHidden: isHidden)
    }

    func didPressAddToken(in viewController: UIViewController, with addressString: String) {
        let initialState: NewTokenInitialState
        if let walletAddress = AlphaWallet.Address(string: addressString.trimmingCharacters(in: .whitespacesAndNewlines)) {
            initialState = .address(walletAddress)
        } else {
            initialState = .empty
        }
        let coordinator = NewTokenCoordinator(
            analyticsCoordinator: analyticsCoordinator,
            navigationController: navigationController,
            config: config,
            singleChainTokenCoordinators: singleChainTokenCoordinators,
            initialState: initialState,
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
