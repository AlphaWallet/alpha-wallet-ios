// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import TrustKeystore
import BigInt

protocol SellTicketsCoordinatorDelegate: class {
    func didClose(in coordinator: SellTicketsCoordinator)
    func didFinishSuccessfully(in coordinator: SellTicketsCoordinator)
    func didFail(in coordinator: SellTicketsCoordinator)
}

class SellTicketsCoordinator: Coordinator {
    var coordinators: [Coordinator] = []
    var ticketHolder: TicketHolder
    var linkExpiryDate: Date
    var ethCost: String
    var dollarCost: String
    var walletAddress: String
    var paymentFlow: PaymentFlow
    var keystore: Keystore
    var session: WalletSession
    var account: Account
    var viewController: UIViewController
    var statusViewController: StatusViewController?
    weak var delegate: SellTicketsCoordinatorDelegate?
    var status = StatusViewControllerViewModel.State.processing {
        didSet {
            statusViewController?.configure(viewModel: .init(
                    state: status,
                    inProgressText: R.string.localizable.aClaimTicketInProgressTitle(),
                    succeededTextText: R.string.localizable.aClaimTicketSuccessTitle(),
                    failedText: R.string.localizable.aClaimTicketFailedTitle()
            ))
        }
    }

    init(ticketHolder: TicketHolder, linkExpiryDate: Date, ethCost: String, dollarCost: String, walletAddress: String, paymentFlow: PaymentFlow, keystore: Keystore, session: WalletSession, account: Account, on viewController: UIViewController) {
        self.ticketHolder = ticketHolder
        self.linkExpiryDate = linkExpiryDate
        self.ethCost = ethCost
        self.dollarCost = dollarCost
        self.walletAddress = walletAddress
        self.paymentFlow = paymentFlow
        self.keystore = keystore
        self.session = session
        self.account = account
        self.viewController = viewController
    }

    func start() {
        guard let address = validateAddress() else { return }
        showProgressViewController()
        sell(address: address)
    }

    private func showProgressViewController() {
        statusViewController = StatusViewController()
        if let vc = statusViewController {
            vc.delegate = self
            vc.configure(viewModel: .init(
                    state: .processing,
                    inProgressText: R.string.localizable.aWalletTicketTokenSellInProgressTitle(),
                    succeededTextText: R.string.localizable.aWalletTicketTokenSellSuccessTitle(),
                    failedText: R.string.localizable.aWalletTicketTokenSellFailedTitle()
            ))
            vc.modalPresentationStyle = .overCurrentContext
            viewController.present(vc, animated: true)
        }
    }

    //TODO code is for transfers. Convert to sell
    private func sell(address: Address) {
        if case .send(let transferType) = paymentFlow {
            let transaction = UnconfirmedTransaction(
                    transferType: transferType,
                    value: BigInt(0),
                    to: address,
                    data: Data(),
                    gasLimit: .none,
                    gasPrice: nil,
                    nonce: .none,
                    v: .none,
                    r: .none,
                    s: .none,
                    expiry: .none,
                    indices: ticketHolder.ticketIndices
            )

            let configurator = TransactionConfigurator(
                    session: session,
                    account: account,
                    transaction: transaction
            )
            configurator.load { [weak self] result in
                guard let `self` = self else { return }
                switch result {
                case .success:
                    self.sendTransaction(with: configurator)
                case .failure(let error):
                    self.processFailed()
                }
            }
        }
    }

    //TODO code is for transfers. Convert to sell (if necessary)
    private func sendTransaction(with configurator: TransactionConfigurator) {
        let unsignedTransaction = configurator.formUnsignedTransaction()
        let sendTransactionCoordinator = SendTransactionCoordinator(
                session: session,
                keystore: keystore,
                confirmType: .signThenSend)
        sendTransactionCoordinator.send(transaction: unsignedTransaction) { [weak self] result in
            if let celf = self {
                switch result {
                case .success(let type):
                    celf.processSuccessful()
                case .failure(let error):
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

extension SellTicketsCoordinator: StatusViewControllerDelegate {
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
