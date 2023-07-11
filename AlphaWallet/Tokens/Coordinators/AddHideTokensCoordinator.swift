// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol AddHideTokensCoordinatorDelegate: AnyObject {
    func didClose(in coordinator: AddHideTokensCoordinator)
}

class AddHideTokensCoordinator: Coordinator {
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainNameResolutionServiceType
    private let navigationController: UINavigationController
    private let sessionsProvider: SessionsProvider
    private lazy var viewModel = AddHideTokensViewModel(
        tokenCollection: tokenCollection,
        tokensFilter: tokensFilter,
        sessionsProvider: sessionsProvider,
        tokenImageFetcher: tokenImageFetcher,
        tokensService: tokensService)

    private lazy var rootViewController: AddHideTokensViewController = {
        let viewController = AddHideTokensViewController(viewModel: viewModel)
        viewController.hidesBottomBarWhenPushed = true
        viewController.delegate = self
        viewController.navigationItem.largeTitleDisplayMode = .never
        viewController.navigationItem.rightBarButtonItem = UIBarButtonItem.addButton(self, selector: #selector(addTokenButtonSelected))

        return viewController
    }()
    private let serversProvider: ServersProvidable
    private let tokenCollection: TokensProcessingPipeline
    private let tokensFilter: TokensFilter
    private let wallet: Wallet
    private let tokenImageFetcher: TokenImageFetcher
    private let tokensService: TokensService

    var coordinators: [Coordinator] = []
    weak var delegate: AddHideTokensCoordinatorDelegate?

    init(tokensFilter: TokensFilter,
         wallet: Wallet,
         tokenCollection: TokensProcessingPipeline,
         analytics: AnalyticsLogger,
         domainResolutionService: DomainNameResolutionServiceType,
         navigationController: UINavigationController,
         serversProvider: ServersProvidable,
         sessionsProvider: SessionsProvider,
         tokenImageFetcher: TokenImageFetcher,
         tokensService: TokensService) {

        self.tokensService = tokensService
        self.tokenImageFetcher = tokenImageFetcher
        self.wallet = wallet
        self.serversProvider = serversProvider
        self.tokenCollection = tokenCollection
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
        self.navigationController = navigationController
        self.sessionsProvider = sessionsProvider
        self.tokensFilter = tokensFilter
    }

    func start() {
        navigationController.pushViewController(rootViewController, animated: true)
    }

    @objc private func addTokenButtonSelected(_ sender: UIBarButtonItem) {
        didPressAddToken(in: rootViewController, with: "")
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

    func didPressAddToken(in viewController: UIViewController, with addressString: String) {
        let initialState: NewTokenInitialState
        if let walletAddress = AlphaWallet.Address(string: addressString.trimmingCharacters(in: .whitespacesAndNewlines)) {
            initialState = .address(walletAddress)
        } else {
            initialState = .empty
        }
        let coordinator = NewTokenCoordinator(
            analytics: analytics,
            wallet: wallet,
            navigationController: navigationController,
            serversProvider: serversProvider,
            sessionsProvider: sessionsProvider,
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
