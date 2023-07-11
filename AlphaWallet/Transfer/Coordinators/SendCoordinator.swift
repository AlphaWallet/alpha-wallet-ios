import Foundation
import UIKit
import BigInt
import AlphaWalletFoundation

protocol SendCoordinatorDelegate: CanOpenURL, BuyCryptoDelegate {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: SendCoordinator)
    func didFinish(_ result: ConfirmResult, in coordinator: SendCoordinator)
    func didCancel(in coordinator: SendCoordinator)
}

class SendCoordinator: Coordinator {
    private let transactionType: TransactionType
    private let session: WalletSession
    private let keystore: Keystore
    private let tokensPipeline: TokensProcessingPipeline
    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainNameResolutionServiceType
    private var transactionConfirmationResult: ConfirmResult? = .none
    private let sessionsProvider: SessionsProvider
    private let networkService: NetworkService
    private let tokenImageFetcher: TokenImageFetcher
    private let tokensService: TokensService

    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []
    lazy var sendViewController: SendViewController = {
        return makeSendViewController()
    }()

    weak var delegate: SendCoordinatorDelegate?

    init(transactionType: TransactionType,
         navigationController: UINavigationController,
         session: WalletSession,
         sessionsProvider: SessionsProvider,
         keystore: Keystore,
         tokensPipeline: TokensProcessingPipeline,
         assetDefinitionStore: AssetDefinitionStore,
         analytics: AnalyticsLogger,
         domainResolutionService: DomainNameResolutionServiceType,
         networkService: NetworkService,
         tokenImageFetcher: TokenImageFetcher,
         tokensService: TokensService) {

        self.tokensService = tokensService
        self.tokenImageFetcher = tokenImageFetcher
        self.networkService = networkService
        self.sessionsProvider = sessionsProvider
        self.transactionType = transactionType
        self.navigationController = navigationController
        self.session = session
        self.keystore = keystore
        self.tokensPipeline = tokensPipeline
        self.assetDefinitionStore = assetDefinitionStore
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
    }

    func start() {
        navigationController.pushViewController(sendViewController, animated: true)
    }

    private func makeSendViewController() -> SendViewController {
        let viewModel = SendViewModel(
            transactionType: transactionType,
            session: session,
            tokensPipeline: tokensPipeline,
            sessionsProvider: sessionsProvider,
            tokensService: tokensService)

        let controller = SendViewController(
            viewModel: viewModel,
            domainResolutionService: domainResolutionService,
            tokenImageFetcher: tokenImageFetcher)

        controller.delegate = self
        controller.navigationItem.largeTitleDisplayMode = .never
        controller.hidesBottomBarWhenPushed = true

        return controller
    }
}

extension SendCoordinator: ScanQRCodeCoordinatorDelegate {
    func didCancel(in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
    }

    func didScan(result: String, decodedValue: QrCodeValue, in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
        sendViewController.didScanQRCode(result)
    }
}

extension SendCoordinator: SendViewControllerDelegate {
    func didClose(in viewController: SendViewController) {
        delegate?.didCancel(in: self)
    }

    func openQRCode(in viewController: SendViewController) {
        guard navigationController.ensureHasDeviceAuthorization() else { return }

        let coordinator = ScanQRCodeCoordinator(
            analytics: analytics,
            navigationController: navigationController,
            account: session.account,
            domainResolutionService: domainResolutionService)

        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(fromSource: .sendFungibleScreen, clipboardString: UIPasteboard.general.stringForQRCode)
    }

    func didPressConfirm(transaction: UnconfirmedTransaction, in viewController: SendViewController) {
        let configuration: TransactionType.Configuration = .sendFungiblesTransaction(confirmType: .signThenSend)

        let coordinator = TransactionConfirmationCoordinator(
            presentingViewController: navigationController,
            session: session,
            transaction: transaction,
            configuration: configuration,
            analytics: analytics,
            domainResolutionService: domainResolutionService,
            keystore: keystore,
            tokensService: tokensPipeline,
            networkService: networkService)

        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start(fromSource: .sendFungible)
    }
}

extension SendCoordinator: TransactionConfirmationCoordinatorDelegate {
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: Error) {
        UIApplication.shared
            .presentedViewController(or: navigationController)
            .displayError(message: error.localizedDescription)
    }

    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator) {
        delegate?.didSendTransaction(transaction, inCoordinator: self)
    }

    func didFinish(_ result: ConfirmResult, in coordinator: TransactionConfirmationCoordinator) {
        coordinator.close { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.removeCoordinator(coordinator)

            strongSelf.transactionConfirmationResult = result

            let coordinator = TransactionInProgressCoordinator(presentingViewController: strongSelf.navigationController, server: strongSelf.session.server)
            coordinator.delegate = strongSelf
            strongSelf.addCoordinator(coordinator)

            coordinator.start()
        }
    }

    func didClose(in coordinator: TransactionConfirmationCoordinator) {
        removeCoordinator(coordinator)
    }

    func buyCrypto(wallet: Wallet, server: RPCServer, viewController: UIViewController, source: Analytics.BuyCryptoSource) {
        delegate?.buyCrypto(wallet: wallet, server: server, viewController: viewController, source: .transactionActionSheetInsufficientFunds)
    }
}

extension SendCoordinator: TransactionInProgressCoordinatorDelegate {

    func didDismiss(in coordinator: TransactionInProgressCoordinator) {
        removeCoordinator(coordinator)

        guard case .some(let result) = transactionConfirmationResult else { return }
        delegate?.didFinish(result, in: self)
    }
}

extension SendCoordinator: CanOpenURL {
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
