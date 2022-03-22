// Copyright © 2022 Stormbird PTE. LTD.

import UIKit
import BigInt
import PromiseKit
import Result

protocol TokenSwapCoordinatorDelegate: class, CanOpenURL {
    func didSentApproveTransaction(transaction: SentTransaction, in coordinator: TokenSwapCoordinator)
    func didSentSwapTransaction(transaction: SentTransaction, in coordinator: TokenSwapCoordinator)
    func openFiatOnRamp(wallet: Wallet, server: RPCServer, coordinator: TokenSwapCoordinator, viewController: UIViewController, source: Analytics.FiatOnRampSource)
}

class TokenSwapCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let keystore: Keystore
    private let sessions: ServerDictionary<WalletSession>
    private let analyticsCoordinator: AnalyticsCoordinator
    private let tokenSwapper = TokenSwapper()

    var coordinators: [Coordinator] = []
    weak var delegate: TokenSwapCoordinatorDelegate?

    init(navigationController: UINavigationController, keystore: Keystore, sessions: ServerDictionary<WalletSession>, analyticsCoordinator: AnalyticsCoordinator) {
        self.navigationController = navigationController
        self.keystore = keystore
        self.sessions = sessions
        self.analyticsCoordinator = analyticsCoordinator
    }

    func start() {
        let vc = SwapViewController(wallet: keystore.currentWallet.address, tokenSwapper: tokenSwapper)
        vc.delegate = self
        navigationController.pushViewController(vc, animated: true)
    }
}

extension TokenSwapCoordinator {
    enum functional {}
}

fileprivate extension TokenSwapCoordinator.functional {
    static func isTransactionErc20Approval(_ transaction: SentTransaction) -> Bool {
        let data = transaction.original.data
        if let function = DecodedFunctionCall(data: data) {
            switch function.type {
            case .erc1155SafeTransfer, .erc1155SafeBatchTransfer, .erc20Transfer, .nativeCryptoTransfer, .others:
                return false
            case .erc20Approve:
                return true
            }
        } else if data.isEmpty {
            return false
        } else {
            return false
        }
    }
}

extension TokenSwapCoordinator: SwapViewControllerDelegate {
    func promptToSwap(unsignedTransaction: UnsignedSwapTransaction, fromToken: TokenToSwap, fromAmount: BigUInt , toToken: TokenToSwap, toAmount: BigUInt, in viewController: SwapViewController) {
        let (transaction, configuration) = tokenSwapper.buildSwapTransaction(keystore: keystore, unsignedTransaction: unsignedTransaction, fromToken: fromToken, fromAmount: fromAmount, toToken: toToken, toAmount: toAmount)
        let coordinator = TransactionConfirmationCoordinator(presentingViewController: navigationController, session: sessions[unsignedTransaction.server], transaction: transaction, configuration: configuration, analyticsCoordinator: analyticsCoordinator)
        addCoordinator(coordinator)
        coordinator.delegate = self
        coordinator.start(fromSource: .swap)
    }

    func promptForErc20Approval(token: AlphaWallet.Address, server: RPCServer, owner: AlphaWallet.Address, spender: AlphaWallet.Address, amount: BigUInt, in viewController: SwapViewController) -> Promise<EthereumTransaction.Id> {
        let (transaction, configuration) = Erc20.buildApproveTransaction(keystore: keystore, token: token, server: server, owner: owner, spender: spender, amount: amount)
        return firstly {
            TransactionConfirmationCoordinator.promise(navigationController, session: sessions[server], coordinator: self, transaction: transaction, configuration: configuration, analyticsCoordinator: analyticsCoordinator, source: .swapApproval, delegate: self)
        }.map { confirmationResult in
            switch confirmationResult {
            case .signedTransaction, .sentRawTransaction:
                NSLog("xxx unexpected confirmationResult when prompted for approval")
                //Unexpected. Programmatic error
                throw SwapError.unknownError
            case .sentTransaction(let transaction):
                NSLog("xxx sentTransaction for approve. Returning true from promise")
                return transaction.id
            }
        }.recover { error -> Promise<EthereumTransaction.Id> in
            //TODO no good to have `DAppError` here, but this is because of `TransactionConfirmationCoordinatorBridgeToPromise`. Maybe good to have a global "UserCancelled" or something? If enum, not too many cases? To avoid `switch`
            if case DAppError.cancelled = error {
                NSLog("xxx cancelled while prompted for approval because error: \(error)")
                throw SwapError.userCancelledApproval
            } else {
                NSLog("xxx recovered from error while prompted for approval. Not user-cancelled. Error: \(error)")
                throw error
            }
        }
    }
}

extension TokenSwapCoordinator: TransactionConfirmationCoordinatorDelegate {
    func didFinish(_ result: ConfirmResult, in coordinator: TransactionConfirmationCoordinator) {
        coordinator.close { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.removeCoordinator(coordinator)
            strongSelf.navigationController.popViewController(animated: true)
        }
    }

    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: AnyError) {
        //hhh1 restore and fix access to `navigationController`
        //coordinator.navigationController.displayError(message: error.prettyError)
    }

    func didClose(in coordinator: TransactionConfirmationCoordinator) {
        removeCoordinator(coordinator)
    }
}

extension TokenSwapCoordinator: CanOpenURL {
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

extension TokenSwapCoordinator: SendTransactionDelegate {
    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator) {
        if functional.isTransactionErc20Approval(transaction) {
            NSLog("xxx didSentTransaction: \(transaction.id) treated as swap's ERC20 approve()")
            delegate?.didSentApproveTransaction(transaction: transaction, in: self)
        } else {
            NSLog("xxx didSentTransaction: \(transaction.id) treated as swap's swap transaction")
            delegate?.didSentSwapTransaction(transaction: transaction, in: self)
        }
    }
}
extension TokenSwapCoordinator: FiatOnRampDelegate {
    func openFiatOnRamp(wallet: Wallet, server: RPCServer, inCoordinator coordinator: TransactionConfirmationCoordinator, viewController: UIViewController) {
        delegate?.openFiatOnRamp(wallet: wallet, server: server, coordinator: self, viewController: viewController, source: .transactionActionSheetInsufficientFunds)
    }
}