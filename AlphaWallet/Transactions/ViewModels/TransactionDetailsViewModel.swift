// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation
import UIKit

struct TransactionDetailsViewModel {
    private let transactionViewModel: TransactionViewModel
    private let transaction: Transaction
    private let chainState: ChainState
    private let fullFormatter = EtherNumberFormatter.full
    private let currencyRate: CurrencyRate?

    private var server: RPCServer {
        return transaction.server
    }

    init(
        transaction: Transaction,
        chainState: ChainState,
        currentWallet: Wallet,
        currencyRate: CurrencyRate?
    ) {
        self.transaction = transaction
        self.chainState = chainState
        self.currencyRate = currencyRate
        self.transactionViewModel = TransactionViewModel(
            transaction: transaction,
            chainState: chainState,
            currentWallet: currentWallet
        )
    }

    var title: String {
        return R.string.localizable.transactionNavigationTitle()
    }

    var backgroundColor: UIColor {
        return .white
    }

    var createdAt: String {
        return Date.formatter(with: "dd MMM yyyy h:mm:ss a").string(from: transaction.date)
    }

    var createdAtLabelTitle: String {
        return R.string.localizable.transactionTimeLabelTitle()
    }

    var detailsAvailable: Bool {
        return detailsURL != nil
    }

    var shareAvailable: Bool {
        return detailsAvailable
    }

    var detailsURL: URL? {
        return ConfigExplorer(server: server).transactionURL(for: transaction.id)
    }

    var transactionID: String {
        return transaction.id
    }

    var transactionIDLabelTitle: String {
        return R.string.localizable.transactionIdLabelTitle()
    }

    var to: String {
        guard let to = transaction.operation?.to else {
            return transaction.to
        }
        return to
    }

    var toLabelTitle: String {
        return R.string.localizable.transactionToLabelTitle()
    }

    var from: String {
        return transaction.from
    }

    var fromLabelTitle: String {
        return R.string.localizable.transactionFromLabelTitle()
    }

    var gasViewModel: GasViewModel {
        let gasUsed = BigInt(transaction.gasUsed) ?? BigInt()
        let gasPrice = BigInt(transaction.gasPrice) ?? BigInt()
        let gasLimit = BigInt(transaction.gas) ?? BigInt()
        let gasFee: BigInt = {
            switch transaction.state {
            case .completed, .error: return gasPrice * gasUsed
            case .pending, .unknown, .failed: return gasPrice * gasLimit
            }
        }()

        return GasViewModel(fee: gasFee, symbol: server.symbol, currencyRate: currencyRate, formatter: fullFormatter)
    }

    var gasFee: String {
        let feeAndSymbol = gasViewModel.feeText
        return feeAndSymbol
    }

    var gasFeeLabelTitle: String {
        return R.string.localizable.transactionGasFeeLabelTitle()
    }

    var confirmation: String {
        guard let confirmation = chainState.confirmations(fromBlock: transaction.blockNumber) else {
            return "--"
        }
        return String(confirmation)
    }

    var confirmationLabelTitle: String {
        return R.string.localizable.transactionConfirmationLabelTitle()
    }

    var blockNumber: String {
        return String(transaction.blockNumber)
    }

    var blockNumberLabelTitle: String {
        return R.string.localizable.transactionBlockNumberLabelTitle()
    }

    var amountAttributedString: NSAttributedString {
        return transactionViewModel.fullAmountAttributedString
    }

    var shareItem: URL? {
        return detailsURL
    }
}
