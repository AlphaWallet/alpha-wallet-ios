// Copyright © 2018 Stormbird PTE. LTD.

import BigInt
import PromiseKit
import Result

protocol TransferNFTCoordinatorDelegate: class {
    func didClose(in coordinator: TransferNFTCoordinator)
    func didCompleteTransfer(withTransactionConfirmationCoordinator transactionConfirmationCoordinator: TransactionConfirmationCoordinator, result: TransactionConfirmationResult, inCoordinator coordinator: TransferNFTCoordinator)
}

class TransferNFTCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let transferType: TransferType
    private let tokenHolder: TokenHolder
    private let recipient: AlphaWallet.Address
    private let keystore: Keystore
    private let session: WalletSession

    var coordinators: [Coordinator] = []
    weak var delegate: TransferNFTCoordinatorDelegate?

    init(navigationController: UINavigationController, transferType: TransferType, tokenHolder: TokenHolder, recipient: AlphaWallet.Address, keystore: Keystore, session: WalletSession) {
        self.navigationController = navigationController
        self.transferType = transferType
        self.tokenHolder = tokenHolder
        self.recipient = recipient
        self.keystore = keystore
        self.session = session
    }

    func start() {
        let transaction = UnconfirmedTransaction(
                transferType: transferType,
                value: BigInt(0),
                recipient: recipient,
                contract: tokenHolder.contractAddress,
                data: nil,
                tokenId: tokenHolder.tokens[0].id,
                indices: tokenHolder.indices
        )
        let configuration: TransactionConfirmationConfiguration = .sendNftTransaction(confirmType: .signThenSend, keystore: keystore)
        let coordinator = TransactionConfirmationCoordinator(navigationController: navigationController, session: session, transaction: transaction, configuration: configuration)
        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start()
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

    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didCompleteTransaction result: TransactionConfirmationResult) {
        delegate?.didCompleteTransfer(withTransactionConfirmationCoordinator: coordinator, result: result, inCoordinator: self)
    }
}