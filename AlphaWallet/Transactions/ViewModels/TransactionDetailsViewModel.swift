// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation
import UIKit

struct TransactionDetailsViewModel {
    private let transactionViewModel: TransactionViewModel
    private let transactionRow: TransactionRow
    private let chainState: ChainState
    private let fullFormatter = EtherNumberFormatter.full
    private let currencyRate: CurrencyRate?

    private var server: RPCServer {
        return transactionRow.server
    }

    init(
            transactionRow: TransactionRow,
            chainState: ChainState,
            currentWallet: Wallet,
            currencyRate: CurrencyRate?
    ) {
        self.transactionRow = transactionRow
        self.chainState = chainState
        self.currencyRate = currencyRate
        self.transactionViewModel = TransactionViewModel(
            transactionRow: transactionRow,
            chainState: chainState,
            currentWallet: currentWallet
        )
    }

    var title: String {
        return R.string.localizable.transactionNavigationTitle(preferredLanguages: Languages.preferred())
    }

    var backgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }

    var createdAt: String {
        return Date.formatter(with: "dd MMM yyyy h:mm:ss a").string(from: transactionRow.date)
    }

    var createdAtLabelTitle: String {
        return R.string.localizable.transactionTimeLabelTitle(preferredLanguages: Languages.preferred())
    }

    var detailsAvailable: Bool {
        return detailsURL != nil
    }

    var shareAvailable: Bool {
        return detailsAvailable
    }

    var addressCopiedText: String {
        return R.string.localizable.requestAddressCopiedTitle(preferredLanguages: Languages.preferred())
    }

    var detailsURL: URL? {
        return ConfigExplorer(server: server).transactionURL(for: transactionRow.id)?.url
    }

    var detailsButtonText: String {
        if let name = ConfigExplorer(server: server).transactionURL(for: transactionRow.id)?.name {
            return R.string.localizable.viewIn(name)
        } else {
            return R.string.localizable.moreDetails(preferredLanguages: Languages.preferred())
        }
    }

    var transactionID: String {
        return transactionRow.id
    }

    var transactionIDLabelTitle: String {
        return R.string.localizable.transactionIdLabelTitle(preferredLanguages: Languages.preferred())
    }

    var to: String {
        switch transactionRow {
        case .standalone(let transaction):
            if let to = transaction.operation?.to {
                return to
            } else {
                return transaction.to
            }
        case .group(let transaction):
            return transaction.to
        case .item(_, operation: let operation):
            return operation.to
        }
    }

    var toLabelTitle: String {
        return R.string.localizable.transactionToLabelTitle(preferredLanguages: Languages.preferred())
    }

    var from: String {
        return transactionRow.from
    }

    var fromLabelTitle: String {
        return R.string.localizable.transactionFromLabelTitle(preferredLanguages: Languages.preferred())
    }

    var gasViewModel: GasViewModel {
        let gasUsed = BigInt(transactionRow.gasUsed) ?? BigInt()
        let gasPrice = BigInt(transactionRow.gasPrice) ?? BigInt()
        let gasLimit = BigInt(transactionRow.gas) ?? BigInt()
        let gasFee: BigInt = {
            switch transactionRow.state {
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
        return R.string.localizable.transactionGasFeeLabelTitle(preferredLanguages: Languages.preferred())
    }

    var confirmation: String {
        guard let confirmation = chainState.confirmations(fromBlock: transactionRow.blockNumber) else {
            return "--"
        }
        return String(confirmation)
    }

    var confirmationLabelTitle: String {
        return R.string.localizable.transactionConfirmationLabelTitle(preferredLanguages: Languages.preferred())
    }

    var blockNumber: String {
        return String(transactionRow.blockNumber)
    }

    var blockNumberLabelTitle: String {
        return R.string.localizable.transactionBlockNumberLabelTitle(preferredLanguages: Languages.preferred())
    }

    var nonce: String {
        String(transactionRow.nonce)
    }

    var nonceLabelTitle: String {
        R.string.localizable.transactionNonceLabelTitle(preferredLanguages: Languages.preferred())
    }

    var amountAttributedString: NSAttributedString {
        return transactionViewModel.fullAmountAttributedString
    }

    var shareItem: URL? {
        return detailsURL
    }
}
