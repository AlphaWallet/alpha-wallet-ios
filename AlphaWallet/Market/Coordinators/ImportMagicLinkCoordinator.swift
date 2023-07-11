// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletFoundation

protocol ImportMagicLinkCoordinatorDelegate: AnyObject, CanOpenURL, BuyCryptoDelegate {
    func viewControllerForPresenting(in coordinator: ImportMagicLinkCoordinator) -> UIViewController?
    func didClose(in coordinator: ImportMagicLinkCoordinator)
}

class ImportMagicLinkCoordinator: Coordinator {
    private let analytics: AnalyticsLogger
    private let config: Config
    private var importTokenViewController: ImportMagicTokenViewController?
    private let assetDefinitionStore: AssetDefinitionStore
    private let keystore: Keystore
    private let tokensService: TokensProcessingPipeline
    private let session: WalletSession
    private let domainResolutionService: DomainNameResolutionServiceType
    private let networkService: NetworkService
    private let controller: ImportMagicLinkController
    private var cancelable = Set<AnyCancellable>()

    var coordinators: [Coordinator] = []
    weak var delegate: ImportMagicLinkCoordinatorDelegate?

    init(analytics: AnalyticsLogger,
         session: WalletSession,
         config: Config,
         assetDefinitionStore: AssetDefinitionStore,
         keystore: Keystore,
         tokensService: TokensProcessingPipeline,
         networkService: NetworkService,
         domainResolutionService: DomainNameResolutionServiceType,
         importToken: TokenImportable & TokenOrContractFetchable,
         reachability: ReachabilityManagerProtocol) {

        self.networkService = networkService
        self.domainResolutionService = domainResolutionService
        self.analytics = analytics
        self.session = session
        self.config = config
        self.assetDefinitionStore = assetDefinitionStore
        self.keystore = keystore
        self.tokensService = tokensService

        controller = ImportMagicLinkController(
            session: session,
            assetDefinitionStore: assetDefinitionStore,
            keystore: keystore,
            tokensService: tokensService,
            networkService: networkService,
            importToken: importToken,
            reachability: reachability)

        controller.claimPaidSignedOrderPublisher
            .sink { [weak self] in self?.claimPaidOrder($0) }
            .store(in: &cancelable)

        controller.displayViewPublisher
            .sink { [weak self] in self?.displayImportUniversalLinkView() }
            .store(in: &cancelable)

        controller.viewStatePublisher
            .sink { [weak self] viewState in
                guard let vc = self?.importTokenViewController else { return }
                var viewModel = vc.viewModel

                vc.url = viewState.url
                vc.contract = viewState.contract

                viewModel.state = viewState.state
                viewModel.tokenHolder = viewState.tokenHolder
                viewModel.count = viewState.count
                viewModel.cost = viewState.cost

                vc.configure(viewModel: viewModel)
            }.store(in: &cancelable)
    }

    private func claimPaidOrder(_ data: (signedOrder: SignedOrder, token: Token)) {
        guard let navigationController = importTokenViewController?.navigationController else { return }

        let coordinator = ClaimPaidOrderCoordinator(
            navigationController: navigationController,
            keystore: keystore,
            session: session,
            token: data.token,
            signedOrder: data.signedOrder,
            analytics: analytics,
            domainResolutionService: domainResolutionService,
            assetDefinitionStore: assetDefinitionStore,
            tokensService: tokensService,
            networkService: networkService)

        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }

    func start(url: URL) -> Bool {
        return controller.start(url: url)
    }

    private func displayImportUniversalLinkView() {
        guard let presentingViewController = delegate?.viewControllerForPresenting(in: self) else { return }

        let viewController = ImportMagicTokenViewController(
            assetDefinitionStore: assetDefinitionStore,
            session: session,
            viewModel: .init(state: .validating, server: session.server))
        viewController.delegate = self

        importTokenViewController = viewController

        let nc = NavigationController(rootViewController: viewController)
        nc.makePresentationFullScreenForiOS13Migration()
        presentingViewController.present(nc, animated: true)
    }

    private func claimPaidSignedOrder(signedOrder: SignedOrder, token: Token) {
        guard let navigationController = importTokenViewController?.navigationController else { return }

        let coordinator = ClaimPaidOrderCoordinator(
            navigationController: navigationController,
            keystore: keystore,
            session: session,
            token: token,
            signedOrder: signedOrder,
            analytics: analytics,
            domainResolutionService: domainResolutionService,
            assetDefinitionStore: assetDefinitionStore,
            tokensService: tokensService,
            networkService: networkService)

        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }
}
// swiftlint:enable type_body_length

extension ImportMagicLinkCoordinator: ClaimOrderCoordinatorDelegate {
    func buyCrypto(wallet: Wallet, server: RPCServer, viewController: UIViewController, source: Analytics.BuyCryptoSource) {
        delegate?.buyCrypto(wallet: wallet, server: server, viewController: viewController, source: source)
    }

    func coordinator(_ coordinator: ClaimPaidOrderCoordinator, didFailTransaction error: Error) {
        controller.completeClaimPaidSignedOrder(with: .failure(error))
    }

    func didClose(in coordinator: ClaimPaidOrderCoordinator) {
        removeCoordinator(coordinator)
    }

    func coordinator(_ coordinator: ClaimPaidOrderCoordinator, didCompleteTransaction result: ConfirmResult) {
        removeCoordinator(coordinator)
        controller.completeClaimPaidSignedOrder(with: .success(result))
    }
}

extension ImportMagicLinkCoordinator: ImportMagicTokenViewControllerDelegate {
    func didPressDone(in viewController: ImportMagicTokenViewController) {
        viewController.dismiss(animated: true)
        delegate?.didClose(in: self)
    }

    func didPressImport(in viewController: ImportMagicTokenViewController) {
        controller.process()
    }
}

extension ImportMagicLinkCoordinator: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}
