//
//  TransferCollectiblesCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.12.2021.
//

import UIKit
import BigInt
import AlphaWalletFoundation

protocol TransferCollectiblesCoordinatorDelegate: CanOpenURL, SendTransactionDelegate, BuyCryptoDelegate {
    func didFinish(_ result: ConfirmResult, in coordinator: TransferCollectiblesCoordinator)
    func didSelectTokenHolder(tokenHolder: TokenHolder, in coordinator: TransferCollectiblesCoordinator)
    func didCancel(in coordinator: TransferCollectiblesCoordinator)
}

class TransferCollectiblesCoordinator: Coordinator {
    private lazy var sendViewController: SendSemiFungibleTokenViewController = {
        return makeTransferTokensCardViaWalletAddressViewController(token: token, tokenHolders: filteredTokenHolders)
    }()
    private let keystore: Keystore
    private let token: Token
    private let session: WalletSession
    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainNameResolutionServiceType
    private let filteredTokenHolders: [TokenHolder]
    private var transactionConfirmationResult: ConfirmResult? = .none
    private let tokensService: TokensProcessingPipeline
    private let networkService: NetworkService
    private let tokenImageFetcher: TokenImageFetcher

    weak var delegate: TransferCollectiblesCoordinatorDelegate?
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(session: WalletSession,
         navigationController: UINavigationController,
         keystore: Keystore,
         filteredTokenHolders: [TokenHolder],
         token: Token,
         assetDefinitionStore: AssetDefinitionStore,
         analytics: AnalyticsLogger,
         domainResolutionService: DomainNameResolutionServiceType,
         tokensService: TokensProcessingPipeline,
         networkService: NetworkService,
         tokenImageFetcher: TokenImageFetcher) {

        self.tokenImageFetcher = tokenImageFetcher
        self.networkService = networkService
        self.tokensService = tokensService
        self.filteredTokenHolders = filteredTokenHolders
        self.session = session
        self.keystore = keystore
        self.navigationController = navigationController
        self.token = token
        self.assetDefinitionStore = assetDefinitionStore
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
        navigationController.navigationBar.isTranslucent = false
    }

    func start() {
        sendViewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(sendViewController, animated: true)
    }

    private func makeTransferTokensCardViaWalletAddressViewController(token: Token, tokenHolders: [TokenHolder]) -> SendSemiFungibleTokenViewController {
        let viewModel = SendSemiFungibleTokenViewModel(token: token, tokenHolders: tokenHolders)
        let tokenCardViewFactory = TokenCardViewFactory(
            token: token,
            assetDefinitionStore: assetDefinitionStore,
            wallet: session.account,
            tokenImageFetcher: tokenImageFetcher)

        let controller = SendSemiFungibleTokenViewController(
            viewModel: viewModel,
            tokenCardViewFactory: tokenCardViewFactory,
            domainResolutionService: domainResolutionService)

        controller.delegate = self

        return controller
    }
}

extension TransferCollectiblesCoordinator: SendSemiFungibleTokenViewControllerDelegate {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }

    func didSelectTokenHolder(tokenHolder: TokenHolder, in viewController: SendSemiFungibleTokenViewController) {
        delegate?.didSelectTokenHolder(tokenHolder: tokenHolder, in: self)
    }

    func didEnterWalletAddress(tokenHolders: [TokenHolder], to recipient: AlphaWallet.Address, in viewController: SendSemiFungibleTokenViewController) {
        do {
            // TODO: verify if tokenHolders are same for TransactionType.erc1155(token, tokenHolders)
            let transactionType = TransactionType(nonFungibleToken: token, tokenHolders: tokenHolders)

            let coordinator = TransactionConfirmationCoordinator(
                presentingViewController: navigationController,
                session: session,
                transaction: try transactionType.buildSendErc1155Token(recipient: recipient, account: session.account.address),
                configuration: .sendNftTransaction(confirmType: .signThenSend),
                analytics: analytics,
                domainResolutionService: domainResolutionService,
                keystore: keystore,
                tokensService: tokensService,
                networkService: networkService)

            addCoordinator(coordinator)
            coordinator.delegate = self
            coordinator.start(fromSource: .sendNft)
        } catch {
            UIApplication.shared
                .presentedViewController(or: navigationController)
                .displayError(message: error.localizedDescription)
        }
    }

    func openQRCode(in controller: SendSemiFungibleTokenViewController) {
        guard navigationController.ensureHasDeviceAuthorization() else { return }

        let coordinator = ScanQRCodeCoordinator(
            analytics: analytics,
            navigationController: navigationController,
            account: session.account,
            domainResolutionService: domainResolutionService)

        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(fromSource: .addressTextField)
    }

    func didClose(in viewController: SendSemiFungibleTokenViewController) {
        delegate?.didCancel(in: self)
    }
}

extension TransferCollectiblesCoordinator: ScanQRCodeCoordinatorDelegate {

    func didCancel(in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
    }

    func didScan(result: String, decodedValue: QrCodeValue, in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
        sendViewController.didScanQRCode(result)
    }
}

extension TransferCollectiblesCoordinator: TransactionConfirmationCoordinatorDelegate {
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: Error) {
        UIApplication.shared
            .presentedViewController(or: navigationController)
            .displayError(message: error.localizedDescription)
    }

    func didClose(in coordinator: TransactionConfirmationCoordinator) {
        removeCoordinator(coordinator)
    }

    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator) {
        delegate?.didSendTransaction(transaction, inCoordinator: coordinator)
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

    func buyCrypto(wallet: Wallet, server: RPCServer, viewController: UIViewController, source: Analytics.BuyCryptoSource) {
        delegate?.buyCrypto(wallet: wallet, server: server, viewController: viewController, source: .transactionActionSheetInsufficientFunds)
    }
}

extension TransferCollectiblesCoordinator: TransactionInProgressCoordinatorDelegate {
    func didDismiss(in coordinator: TransactionInProgressCoordinator) {
        removeCoordinator(coordinator)

        guard case .some(let result) = transactionConfirmationResult else { return }
        delegate?.didFinish(result, in: self)
    }
}
