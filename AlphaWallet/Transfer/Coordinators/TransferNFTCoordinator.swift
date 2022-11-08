// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import BigInt
import AlphaWalletFoundation

protocol TransferNFTCoordinatorDelegate: CanOpenURL, SendTransactionDelegate, BuyCryptoDelegate {
    func didSelectTokenHolder(tokenHolder: TokenHolder, in coordinator: TransferNFTCoordinator)
    func didFinish(_ result: ConfirmResult, in coordinator: TransferNFTCoordinator)
    func didCancel(in coordinator: TransferNFTCoordinator)
}

class TransferNFTCoordinator: Coordinator {
    private lazy var sendViewController: SendSemiFungibleTokenViewController = {
        let tokenCardViewFactory: TokenCardViewFactory = .init(token: token, assetDefinitionStore: assetDefinitionStore, analytics: analytics, keystore: keystore, wallet: session.account)
        let viewModel = SendSemiFungibleTokenViewModel(token: token, tokenHolders: [tokenHolder])
        let controller = SendSemiFungibleTokenViewController(viewModel: viewModel, tokenCardViewFactory: tokenCardViewFactory, domainResolutionService: domainResolutionService)
        controller.delegate = self
        controller.navigationItem.largeTitleDisplayMode = .never
        controller.hidesBottomBarWhenPushed = true

        return controller
    }()

    private let keystore: Keystore
    private let token: Token
    private let session: WalletSession
    private let assetDefinitionStore: AssetDefinitionStore
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainResolutionServiceType
    private let tokenHolder: TokenHolder
    private var transactionConfirmationResult: ConfirmResult? = .none
    private let transactionType: TransactionType
    private let tokensService: TokenViewModelState

    weak var delegate: TransferNFTCoordinatorDelegate?
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(
            session: WalletSession,
            navigationController: UINavigationController,
            keystore: Keystore,
            tokenHolder: TokenHolder,
            token: Token,
            transactionType: TransactionType,
            assetDefinitionStore: AssetDefinitionStore,
            analytics: AnalyticsLogger,
            domainResolutionService: DomainResolutionServiceType,
            tokensService: TokenViewModelState
    ) {
        self.tokensService = tokensService
        self.transactionType = transactionType
        self.tokenHolder = tokenHolder
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
        navigationController.pushViewController(sendViewController, animated: true)
    }
}

extension TransferNFTCoordinator: SendSemiFungibleTokenViewControllerDelegate {
    func didEnterWalletAddress(tokenHolders: [AlphaWalletFoundation.TokenHolder], to recipient: AlphaWalletFoundation.AlphaWallet.Address, in viewController: SendSemiFungibleTokenViewController) {
        do {
            guard let tokenHolder = tokenHolders.first else { throw TransactionConfiguratorError.impossibleToBuildConfiguration }
            guard let token = tokenHolder.tokens.first else { throw TransactionConfiguratorError.impossibleToBuildConfiguration }

            let data: Data
            switch self.transactionType {
            case .erc875Token(let token, _):
                data = (try? Erc875Transfer(contractAddress: token.contractAddress, recipient: recipient, indices: tokenHolder.indices).encodedABI()) ?? Data()
            case .erc721Token, .erc721ForTicketToken:
                data = (try? Erc721SafeTransferFrom(recipient: recipient, contractAddress: tokenHolder.contractAddress, account: session.account.address, tokenId: token.id).encodedABI()) ?? Data()
            case .nativeCryptocurrency, .erc20Token, .erc1155Token, .dapp, .claimPaidErc875MagicLink, .tokenScript, .prebuilt:
                fatalError()
            }

            let transaction = UnconfirmedTransaction(transactionType: transactionType, value: BigInt(0), recipient: recipient, contract: tokenHolder.contractAddress, data: data)

            let configuration: TransactionType.Configuration = .sendNftTransaction(confirmType: .signThenSend)
            let coordinator = try TransactionConfirmationCoordinator(presentingViewController: navigationController, session: session, transaction: transaction, configuration: configuration, analytics: analytics, domainResolutionService: domainResolutionService, keystore: keystore, assetDefinitionStore: assetDefinitionStore, tokensService: tokensService)
            addCoordinator(coordinator)
            coordinator.delegate = self
            coordinator.start(fromSource: .sendNft)
        } catch {
            UIApplication.shared
                .presentedViewController(or: navigationController)
                .displayError(message: error.prettyError)
        }
    }

    func didSelectTokenHolder(tokenHolder: AlphaWalletFoundation.TokenHolder, in viewController: SendSemiFungibleTokenViewController) {
        delegate?.didSelectTokenHolder(tokenHolder: tokenHolder, in: self)
    }

    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }

    func openQRCode(in controller: SendSemiFungibleTokenViewController) {
        guard navigationController.ensureHasDeviceAuthorization() else { return }

        let coordinator = ScanQRCodeCoordinator(analytics: analytics, navigationController: navigationController, account: session.account, domainResolutionService: domainResolutionService)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(fromSource: .addressTextField)
    }

    func didClose(in viewController: SendSemiFungibleTokenViewController) {
        delegate?.didCancel(in: self)
    }
}

extension TransferNFTCoordinator: ScanQRCodeCoordinatorDelegate {

    func didCancel(in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
    }

    func didScan(result: String, in coordinator: ScanQRCodeCoordinator) {
        removeCoordinator(coordinator)
        sendViewController.didScanQRCode(result)
    }
}

extension TransferNFTCoordinator: TransactionConfirmationCoordinatorDelegate {
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: Error) {
        UIApplication.shared
            .presentedViewController(or: navigationController)
            .displayError(message: error.prettyError)
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

            let coordinator = TransactionInProgressCoordinator(presentingViewController: strongSelf.navigationController)
            coordinator.delegate = strongSelf
            strongSelf.addCoordinator(coordinator)

            coordinator.start()
        }
    }

    func buyCrypto(wallet: Wallet, server: RPCServer, viewController: UIViewController, source: Analytics.BuyCryptoSource) {
        delegate?.buyCrypto(wallet: wallet, server: server, viewController: viewController, source: .transactionActionSheetInsufficientFunds)
    }
}

extension TransferNFTCoordinator: TransactionInProgressCoordinatorDelegate {
    func didDismiss(in coordinator: TransactionInProgressCoordinator) {
        removeCoordinator(coordinator)

        guard case .some(let result) = transactionConfirmationResult else { return }
        delegate?.didFinish(result, in: self)
    }
}

