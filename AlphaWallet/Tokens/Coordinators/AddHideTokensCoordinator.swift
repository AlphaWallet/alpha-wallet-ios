// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import PromiseKit

private struct NoContractDetailsDetected: Error {
}

protocol AddHideTokensCoordinatorDelegate: AnyObject {
    func didClose(in coordinator: AddHideTokensCoordinator)
}

class AddHideTokensCoordinator: Coordinator {
    private let analyticsCoordinator: AnalyticsCoordinator
    private let domainResolutionService: DomainResolutionServiceType
    private let navigationController: UINavigationController
    private let importToken: ImportToken
    private lazy var viewModel = AddHideTokensViewModel(tokenCollection: tokenCollection, importToken: importToken, config: config, assetDefinitionStore: assetDefinitionStore)
    private lazy var rootViewController: AddHideTokensViewController = {
        return .init(viewModel: viewModel)
    }()

    private let assetDefinitionStore: AssetDefinitionStore
    private let config: Config
    private let tokenCollection: TokenCollection

    var coordinators: [Coordinator] = []
    weak var delegate: AddHideTokensCoordinatorDelegate?

    init(assetDefinitionStore: AssetDefinitionStore, tokenCollection: TokenCollection, analyticsCoordinator: AnalyticsCoordinator, domainResolutionService: DomainResolutionServiceType, navigationController: UINavigationController, config: Config, importToken: ImportToken) {
        self.config = config
        self.tokenCollection = tokenCollection
        self.analyticsCoordinator = analyticsCoordinator
        self.domainResolutionService = domainResolutionService
        self.navigationController = navigationController
        self.assetDefinitionStore = assetDefinitionStore
        self.importToken = importToken
    }

    func start() {
        rootViewController.delegate = self
        navigationController.pushViewController(rootViewController, animated: true)
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
        tokenCollection.tokensDataStore.updateOrderedTokens(with: tokens)
    }

    func didMark(token: Token, in viewController: UIViewController, isHidden: Bool) {
        tokenCollection.tokensDataStore.updateToken(primaryKey: token.primaryKey, action: .isHidden(isHidden))
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
            initialState: initialState,
            domainResolutionService: domainResolutionService)
        coordinator.delegate = self
        addCoordinator(coordinator)

        coordinator.start()
    }

    func didClose(in viewController: AddHideTokensViewController) {
        delegate?.didClose(in: self)
    }
}
