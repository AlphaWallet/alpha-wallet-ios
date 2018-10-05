// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import TrustKeystore
import BigInt

protocol TransferNFTCoordinatorDelegate: class {
    func didClose(in coordinator: TransferNFTCoordinator)
    func didFinishSuccessfully(in coordinator: TransferNFTCoordinator)
    func didFail(in coordinator: TransferNFTCoordinator)
}

class TransferNFTCoordinator: Coordinator {
    private let tokenHolder: TokenHolder
    private let walletAddress: String
    private let paymentFlow: PaymentFlow
    private let keystore: Keystore
    private let session: WalletSession
    private let account: Account
    private let viewController: UIViewController
    private var statusViewController: StatusViewController?
    private var address: Address?
    private var status = StatusViewControllerViewModel.State.processing {
        didSet {
            guard let address = address else { return }
            let tokenTypeName = XMLHandler(contract: address.eip55String).getTokenTypeName(.singular)
            statusViewController?.configure(viewModel: .init(
                    state: status,
                    inProgressText: R.string.localizable.aWalletTokenTransferInProgressTitle(tokenTypeName),
                    succeededTextText: R.string.localizable.aWalletTokenTransferSuccessTitle(tokenTypeName),
                    failedText: R.string.localizable.aWalletTokenTransferFailedTitle(tokenTypeName)
            ))
        }
    }

    var coordinators: [Coordinator] = []
    weak var delegate: TransferNFTCoordinatorDelegate?

    init(tokenHolder: TokenHolder, walletAddress: String, paymentFlow: PaymentFlow, keystore: Keystore, session: WalletSession, account: Account, on viewController: UIViewController) {
        self.tokenHolder = tokenHolder
        self.walletAddress = walletAddress
        self.paymentFlow = paymentFlow
        self.keystore = keystore
        self.session = session
        self.account = account
        self.viewController = viewController
    }

    func start() {
        guard let address = validateAddress() else { return }
        self.address = address
        showProgressViewController(address: address)
        transfer(address: address)
    }

    private func showProgressViewController(address: Address) {
        statusViewController = StatusViewController()
        if let vc = statusViewController {
            vc.delegate = self
            let tokenTypeName = XMLHandler(contract: address.eip55String).getTokenTypeName(.singular)
            vc.configure(viewModel: .init(
                    state: .processing,
                    inProgressText: R.string.localizable.aWalletTokenTransferInProgressTitle(tokenTypeName),
                    succeededTextText: R.string.localizable.aWalletTokenTransferSuccessTitle(tokenTypeName),
                    failedText: R.string.localizable.aWalletTokenTransferFailedTitle(tokenTypeName)
            ))
            vc.modalPresentationStyle = .overCurrentContext
            viewController.present(vc, animated: true)
        }
    }

    private func transfer(address: Address) {
        if case .send(let transferType) = paymentFlow {
            let transaction = UnconfirmedTransaction(
                    transferType: transferType,
                    value: BigInt(0),
                    to: address,
                    data: Data(),
                    gasLimit: .none,
                    tokenId: String(tokenHolder.tokens[0].id),
                    gasPrice: nil,
                    nonce: .none,
                    v: .none,
                    r: .none,
                    s: .none,
                    expiry: .none,
                    indices: tokenHolder.indices,
                    tokenIds: .none
            )

            let configurator = TransactionConfigurator(
                    session: session,
                    account: account,
                    transaction: transaction
            )
            configurator.load { [weak self] result in
                guard let strongSelf = self else { return }
                switch result {
                case .success:
                    strongSelf.sendTransaction(with: configurator)
                case .failure:
                    //TODO use the error object or remove it from the case-statement
                    strongSelf.processFailed()
                }
            }
        }
    }

    private func sendTransaction(with configurator: TransactionConfigurator) {
        let unsignedTransaction = configurator.formUnsignedTransaction()
        let sendTransactionCoordinator = SendTransactionCoordinator(
                session: session,
                keystore: keystore,
                confirmType: .signThenSend)
        sendTransactionCoordinator.send(transaction: unsignedTransaction) { [weak self] result in
            if let celf = self {
                switch result {
                case .success:
                    celf.processSuccessful()
                case .failure:
                    //TODO use the error object or remove it from the case-statement
                    celf.processFailed()
                }
            }
        }
    }

    private func processSuccessful() {
        status = .succeeded
    }

    private func processFailed() {
        status = .failed
    }

    private func validateAddress() -> Address? {
        return Address(string: walletAddress)
    }
}

extension TransferNFTCoordinator: StatusViewControllerDelegate {
    func didPressDone(in viewController: StatusViewController) {
        viewController.dismiss(animated: false)
        switch status {
        case .processing:
            delegate?.didClose(in: self)
        case .succeeded:
            delegate?.didFinishSuccessfully(in: self)
        case .failed:
            delegate?.didFail(in: self)
        }
    }
}
