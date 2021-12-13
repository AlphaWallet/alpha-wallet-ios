// Copyright © 2018 Stormbird PTE. LTD.

import BigInt
import PromiseKit
import Result

protocol TransferNFTCoordinatorDelegate: class, CanOpenURL {
    func didClose(in coordinator: TransferNFTCoordinator)
    func didCompleteTransfer(withTransactionConfirmationCoordinator transactionConfirmationCoordinator: TransactionConfirmationCoordinator, result: ConfirmResult, inCoordinator coordinator: TransferNFTCoordinator)
    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TransferNFTCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource)
}

class TransferNFTCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let transactionType: TransactionType
    private let tokenHolder: TokenHolder
    private let recipient: AlphaWallet.Address
    private let keystore: Keystore
    private let session: WalletSession
    private let ethPrice: Subscribable<Double>
    private let analyticsCoordinator: AnalyticsCoordinator
    var coordinators: [Coordinator] = []
    weak var delegate: TransferNFTCoordinatorDelegate?

    init(navigationController: UINavigationController, transactionType: TransactionType, tokenHolder: TokenHolder, recipient: AlphaWallet.Address, keystore: Keystore, session: WalletSession, ethPrice: Subscribable<Double>, analyticsCoordinator: AnalyticsCoordinator) {
        self.navigationController = navigationController
        self.transactionType = transactionType
        self.tokenHolder = tokenHolder
        self.recipient = recipient
        self.keystore = keystore
        self.session = session
        self.ethPrice = ethPrice
        self.analyticsCoordinator = analyticsCoordinator
    }

    func start() {
        let transaction = UnconfirmedTransaction(
                transactionType: transactionType,
                value: BigInt(0),
                recipient: recipient,
                contract: tokenHolder.contractAddress,
                data: nil,
                tokenId: tokenHolder.tokens[0].id,
                indices: tokenHolder.indices
        )

        let tokenInstanceNames = tokenHolder.valuesAll.compactMapValues { $0.nameStringValue }
        let configuration: TransactionConfirmationConfiguration = .sendNftTransaction(confirmType: .signThenSend, keystore: keystore, ethPrice: ethPrice, tokenInstanceNames: tokenInstanceNames)
        let coordinator = TransactionConfirmationCoordinator(presentingViewController: navigationController, session: session, transaction: transaction, configuration: configuration, analyticsCoordinator: analyticsCoordinator)
        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start(fromSource: .sendNft)
    }
}

extension TransferNFTCoordinator: TransactionConfirmationCoordinatorDelegate {
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: AnyError) {
        //TODO improve error message. Several of this delegate func
        coordinator.navigationController.displayError(message: error.localizedDescription)
    }

    func didClose(in coordinator: TransactionConfirmationCoordinator) {
        removeCoordinator(coordinator)
        delegate?.didClose(in: self)
    }

    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didCompleteTransaction result: ConfirmResult) {
        delegate?.didCompleteTransfer(withTransactionConfirmationCoordinator: coordinator, result: result, inCoordinator: self)
    }

    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator) {
        // no-op
    }

    func didFinish(_ result: ConfirmResult, in coordinator: TransactionConfirmationCoordinator) {
        delegate?.didCompleteTransfer(withTransactionConfirmationCoordinator: coordinator, result: result, inCoordinator: self)
    }

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TransactionConfirmationCoordinator, viewController: UIViewController) {
        delegate?.openFiatOnRamp(wallet: wallet, server: server, inCoordinator: self, viewController: viewController, source: .transactionActionSheetInsufficientFunds)
    }
}

extension TransferNFTCoordinator: CanOpenURL {
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
