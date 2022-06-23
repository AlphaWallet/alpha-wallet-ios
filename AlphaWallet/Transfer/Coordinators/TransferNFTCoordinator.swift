// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import BigInt
import Result

protocol TransferNFTCoordinatorDelegate: CanOpenURL, SendTransactionDelegate {
    func didFinish(_ result: ConfirmResult, in coordinator: TransferNFTCoordinator)
    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TransferNFTCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource)
    func didCancel(in coordinator: TransferNFTCoordinator)
}

class TransferNFTCoordinator: Coordinator {
    private lazy var sendViewController: TransferTokensCardViaWalletAddressViewController = {
        return makeTransferTokensCardViaWalletAddressViewController(token: tokenObject, for: tokenHolder, paymentFlow: .send(type: .transaction(transactionType)))
    }()
    private let keystore: Keystore
    private let tokenObject: TokenObject
    private let session: WalletSession
    private let assetDefinitionStore: AssetDefinitionStore
    private let analyticsCoordinator: AnalyticsCoordinator
    private let domainResolutionService: DomainResolutionServiceType
    private let tokenHolder: TokenHolder
    private var transactionConfirmationResult: ConfirmResult? = .none
    private let transactionType: TransactionType

    weak var delegate: TransferNFTCoordinatorDelegate?
    let navigationController: UINavigationController
    var coordinators: [Coordinator] = []

    init(
            session: WalletSession,
            navigationController: UINavigationController,
            keystore: Keystore,
            tokenHolder: TokenHolder,
            tokenObject: TokenObject,
            transactionType: TransactionType,
            assetDefinitionStore: AssetDefinitionStore,
            analyticsCoordinator: AnalyticsCoordinator,
            domainResolutionService: DomainResolutionServiceType
    ) {
        self.transactionType = transactionType
        self.tokenHolder = tokenHolder
        self.session = session
        self.keystore = keystore
        self.navigationController = navigationController
        self.tokenObject = tokenObject
        self.assetDefinitionStore = assetDefinitionStore
        self.analyticsCoordinator = analyticsCoordinator
        self.domainResolutionService = domainResolutionService
        navigationController.navigationBar.isTranslucent = false
    }

    func start() {
        sendViewController.navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(self, selector: #selector(dismiss))
        sendViewController.navigationItem.largeTitleDisplayMode = .never
        navigationController.pushViewController(sendViewController, animated: true)
    }

    @objc private func dismiss() {
        removeAllCoordinators()

        delegate?.didCancel(in: self)
    }

    private func makeTransferTokensCardViaWalletAddressViewController(token: TokenObject, for tokenHolder: TokenHolder, paymentFlow: PaymentFlow) -> TransferTokensCardViaWalletAddressViewController {
        let viewModel = TransferTokensCardViaWalletAddressViewControllerViewModel(token: token, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        let controller = TransferTokensCardViaWalletAddressViewController(analyticsCoordinator: analyticsCoordinator, domainResolutionService: domainResolutionService, token: token, tokenHolder: tokenHolder, paymentFlow: paymentFlow, viewModel: viewModel, assetDefinitionStore: assetDefinitionStore, keystore: keystore, session: session)
        controller.configure()
        controller.delegate = self
        return controller
    }
}

extension TransferNFTCoordinator: TransferTokensCardViaWalletAddressViewControllerDelegate {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }

    func openQRCode(in controller: TransferTokensCardViaWalletAddressViewController) {
        guard navigationController.ensureHasDeviceAuthorization() else { return }

        let coordinator = ScanQRCodeCoordinator(analyticsCoordinator: analyticsCoordinator, navigationController: navigationController, account: session.account, domainResolutionService: domainResolutionService)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(fromSource: .addressTextField)
    }

    func didEnterWalletAddress(tokenHolder: TokenHolder, to recipient: AlphaWallet.Address, paymentFlow: PaymentFlow, in viewController: TransferTokensCardViaWalletAddressViewController) {
        do {
            guard let token = tokenHolder.tokens.first else { throw TransactionConfiguratorError.impossibleToBuildConfiguration }
            let transaction = UnconfirmedTransaction(
                    transactionType: transactionType,
                    value: BigInt(0),
                    recipient: recipient,
                    contract: tokenHolder.contractAddress,
                    data: nil,
                    tokenId: token.id,
                    indices: tokenHolder.indices
            )

            let tokenInstanceNames = tokenHolder.valuesAll.compactMapValues { $0.nameStringValue }
            let configuration: TransactionConfirmationConfiguration = .sendNftTransaction(confirmType: .signThenSend, keystore: keystore, tokenInstanceNames: tokenInstanceNames)

            let coordinator = try TransactionConfirmationCoordinator(presentingViewController: navigationController, session: session, transaction: transaction, configuration: configuration, analyticsCoordinator: analyticsCoordinator, domainResolutionService: domainResolutionService)
            addCoordinator(coordinator)
            coordinator.delegate = self
            coordinator.start(fromSource: .sendNft)
        } catch {
            UIApplication.shared
                .presentedViewController(or: navigationController)
                .displayError(message: error.prettyError)
        }
    }

    func didPressViewInfo(in viewController: TransferTokensCardViaWalletAddressViewController) {
        //showViewEthereumInfo(in: viewController)
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
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: AnyError) {
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

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TransactionConfirmationCoordinator, viewController: UIViewController) {
        delegate?.openFiatOnRamp(wallet: wallet, server: server, inCoordinator: self, viewController: viewController, source: .transactionActionSheetInsufficientFunds)
    }
}

extension TransferNFTCoordinator: TransactionInProgressCoordinatorDelegate {
    func didDismiss(in coordinator: TransactionInProgressCoordinator) {
        removeCoordinator(coordinator)

        guard case .some(let result) = transactionConfirmationResult else { return }
        delegate?.didFinish(result, in: self)
    }
}

