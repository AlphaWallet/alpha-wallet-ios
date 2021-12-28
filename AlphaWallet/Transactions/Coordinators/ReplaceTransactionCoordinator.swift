// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import BigInt
import Result

protocol ReplaceTransactionCoordinatorDelegate: class, CanOpenURL {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: ReplaceTransactionCoordinator)
    func didFinish(_ result: ConfirmResult, in coordinator: ReplaceTransactionCoordinator)
    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: ReplaceTransactionCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource)
}

class ReplaceTransactionCoordinator: Coordinator {
    enum Mode {
        case speedup
        case cancel
    }

    private let analyticsCoordinator: AnalyticsCoordinator
    private let pendingTransactionInformation: (server: RPCServer, data: Data, transactionType: TransactionType, gasPrice: BigInt)
    private let nonce: BigInt
    private let keystore: Keystore
    private let ethPrice: Subscribable<Double>
    private let presentingViewController: UIViewController
    private let session: WalletSession
    private let transaction: TransactionInstance
    private let mode: Mode
    private var transactionConfirmationResult: ConfirmResult? = .none

    private var recipient: AlphaWallet.Address? {
        switch transactionType {
        case .nativeCryptocurrency:
            return AlphaWallet.Address(string: transaction.to)
        case .dapp, .erc20Token, .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .tokenScript, .claimPaidErc875MagicLink:
            return nil
        }
    }
    private var contract: AlphaWallet.Address? {
        switch transactionType {
        case .nativeCryptocurrency:
            return nil
        case .dapp, .erc20Token, .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .tokenScript, .claimPaidErc875MagicLink:
            return AlphaWallet.Address(string: transaction.to)
        }
    }
    private var transactionType: TransactionType {
        switch mode {
        case .speedup:
            return pendingTransactionInformation.transactionType
        case .cancel:
            //Cancel with a 0-value transfer transaction
            return .nativeCryptocurrency(TokensDataStore.etherToken(forServer: pendingTransactionInformation.server), destination: .address(keystore.currentWallet.address), amount: nil)
        }
    }
    private var transactionValue: BigInt {
        switch mode {
        case .speedup:
            return BigInt(transaction.value) ?? 0
        case .cancel:
            return 0
        }
    }
    private var transactionData: Data? {
        switch mode {
        case .speedup:
            return pendingTransactionInformation.data
        case .cancel:
            return nil
        }
    }
    private var transactionConfirmationConfiguration: TransactionConfirmationConfiguration {
        switch mode {
        case .speedup:
            return .speedupTransaction(keystore: keystore, ethPrice: ethPrice)
        case .cancel:
            return .cancelTransaction(keystore: keystore, ethPrice: ethPrice)
        }
    }

    var coordinators: [Coordinator] = []
    weak var delegate: ReplaceTransactionCoordinatorDelegate?

    init?(analyticsCoordinator: AnalyticsCoordinator, keystore: Keystore, ethPrice: Subscribable<Double>, presentingViewController: UIViewController, session: WalletSession, transaction: TransactionInstance, mode: Mode) {
        guard let pendingTransactionInformation = TransactionsStorage.pendingTransactionsInformation[transaction.id] else { return nil }
        guard let nonce = BigInt(transaction.nonce) else { return nil }
        self.pendingTransactionInformation = pendingTransactionInformation
        self.keystore = keystore
        self.ethPrice = ethPrice
        self.analyticsCoordinator = analyticsCoordinator
        self.presentingViewController = presentingViewController
        self.session = session
        self.transaction = transaction
        self.mode = mode
        self.nonce = nonce
    }

    func start() {
        let higherGasPrice = computeGasPriceForReplacementTransaction(pendingTransactionInformation.gasPrice)
        let unconfirmedTransaction = UnconfirmedTransaction(transactionType: transactionType, value: transactionValue, recipient: recipient, contract: contract, data: transactionData, gasPrice: higherGasPrice, nonce: nonce)
        let coordinator = TransactionConfirmationCoordinator(
                presentingViewController: presentingViewController,
                session: session,
                transaction: unconfirmedTransaction,
                configuration: transactionConfirmationConfiguration,
                analyticsCoordinator: analyticsCoordinator
        )
        coordinator.delegate = self
        addCoordinator(coordinator)
        switch mode {
        case .speedup:
            coordinator.start(fromSource: .speedupTransaction)
        case .cancel:
            coordinator.start(fromSource: .cancelTransaction)
        }
    }

    private func computeGasPriceForReplacementTransaction(_ gasPrice: BigInt) -> BigInt {
        gasPrice * 110 / 100
    }
}

extension ReplaceTransactionCoordinator: TransactionConfirmationCoordinatorDelegate {
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: AnyError) {
        //TODO improve error message. Several of this delegate func
        coordinator.navigationController.displayError(message: error.prettyError)
    }

    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator) {
        delegate?.didSendTransaction(transaction, inCoordinator: self)
    }

    func didFinish(_ result: ConfirmResult, in coordinator: TransactionConfirmationCoordinator) {
        coordinator.close { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.removeCoordinator(coordinator)
            strongSelf.transactionConfirmationResult = result

            let coordinator = TransactionInProgressCoordinator(presentingViewController: strongSelf.presentingViewController)
            coordinator.delegate = strongSelf
            strongSelf.addCoordinator(coordinator)

            coordinator.start()
        }
    }

    func didClose(in coordinator: TransactionConfirmationCoordinator) {
        removeCoordinator(coordinator)
    }

    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TransactionConfirmationCoordinator, viewController: UIViewController) {
        let source: Analytics.FiatOnRampSource
        switch mode {
        case .speedup:
            source = .speedupTransactionInsufficientFunds
        case .cancel:
            source = .cancelTransactionInsufficientFunds
        }
        delegate?.openFiatOnRamp(wallet: wallet, server: server, inCoordinator: self, viewController: viewController, source: source)
    }
}

extension ReplaceTransactionCoordinator: TransactionInProgressCoordinatorDelegate {
    func transactionInProgressDidDismiss(in coordinator: TransactionInProgressCoordinator) {
        switch transactionConfirmationResult {
        case .some(let result):
            delegate?.didFinish(result, in: self)
        case .none:
            break
        }
    }
}

extension ReplaceTransactionCoordinator: CanOpenURL {
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
