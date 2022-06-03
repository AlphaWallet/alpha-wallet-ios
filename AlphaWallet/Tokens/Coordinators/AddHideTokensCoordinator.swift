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
    private let importToken: ImportToken
    private lazy var viewModel = AddHideTokensViewModel(tokens: tokens, tokensFilter: tokensFilter, importToken: importToken, config: config)
    private lazy var viewController: AddHideTokensViewController = {
        return .init(viewModel: viewModel, assetDefinitionStore: assetDefinitionStore)
    }()

    private let tokensFilter: TokensFilter
    private let assetDefinitionStore: AssetDefinitionStore
    private let config: Config
    private var tokens: [Token]
    private let tokensDataStore: TokensDataStore

    var coordinators: [Coordinator] = []
    weak var delegate: AddHideTokensCoordinatorDelegate?

    init(tokens: [Token], assetDefinitionStore: AssetDefinitionStore, tokensFilter: TokensFilter, analyticsCoordinator: AnalyticsCoordinator, navigationController: UINavigationController, config: Config, importToken: ImportToken, tokensDataStore: TokensDataStore) {
        self.config = config
        self.tokensFilter = tokensFilter
        self.tokens = tokens
        self.analyticsCoordinator = analyticsCoordinator
        self.navigationController = navigationController
        self.assetDefinitionStore = assetDefinitionStore
        self.importToken = importToken
        self.tokensDataStore = tokensDataStore
    }

    func start() {
        viewController.delegate = self
        navigationController.pushViewController(viewController, animated: true)
    }

    @objc func dismiss() {
        navigationController.dismiss(animated: true)
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
        tokensDataStore.updateOrderedTokens(with: tokens)
    }

    func didMark(token: Token, in viewController: UIViewController, isHidden: Bool) {
        tokensDataStore.updateToken(primaryKey: token.primaryKey, action: .isHidden(isHidden))
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
            importToken: importToken,
            initialState: initialState)
        coordinator.delegate = self
        addCoordinator(coordinator)

        coordinator.start()
    }

    func didClose(viewController: AddHideTokensViewController) {
        delegate?.didClose(coordinator: self)
    }
}
