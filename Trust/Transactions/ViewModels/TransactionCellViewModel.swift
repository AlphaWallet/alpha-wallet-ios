// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation
import UIKit

struct TransactionCellViewModel {

    private let transaction: Transaction
    private let config: Config
    private let chainState: ChainState
    private let currentWallet: Wallet
    private let shortFormatter = EtherNumberFormatter.short

    private let transactionViewModel: TransactionViewModel

    init(
        transaction: Transaction,
        config: Config,
        chainState: ChainState,
        currentWallet: Wallet
    ) {
        self.transaction = transaction
        self.config = config
        self.chainState = chainState
        self.currentWallet = currentWallet
        self.transactionViewModel = TransactionViewModel(
            transaction: transaction,
            config: config,
            chainState: chainState,
            currentWallet: currentWallet
        )
    }

    var confirmations: Int? {
        return chainState.confirmations(fromBlock: transaction.blockNumber)
    }

    private var operationTitle: String? {
        guard let operation = transaction.operation else { return .none }
        switch operation.operationType {
        case .tokenTransfer:
            return String(
                format: NSLocalizedString(
                    "transaction.cell.tokenTransfer.title",
                    value: "Transfer %@",
                    comment: "Transfer token title. Example: Transfer OMG"
                ),
                operation.symbol ?? ""
            )
        case .unknown:
            return .none
        }
    }

    var title: String {
        if let operationTitle = operationTitle {
            return operationTitle
        }
        switch transaction.state {
        case .completed:
            switch transactionViewModel.direction {
            case .incoming: return NSLocalizedString("transaction.cell.received.title", value: "Received", comment: "")
            case .outgoing: return NSLocalizedString("transaction.cell.sent.title", value: "Sent", comment: "")
            }
        case .error:
            return NSLocalizedString("transaction.cell.error.title", value: "Error", comment: "")
        case .failed:
            return NSLocalizedString("transaction.cell.failed.title", value: "Failed", comment: "")
        case .unknown:
            return NSLocalizedString("transaction.cell.unknown.title", value: "Unknown", comment: "")
        case .pending:
            return NSLocalizedString("transaction.cell.pending.title", value: "Pending", comment: "")
        }
    }

    var subTitle: String {
        switch transactionViewModel.direction {
        case .incoming: return "\(transaction.from)"
        case .outgoing: return "\(transaction.to)"
        }
    }

    var subTitleTextColor: UIColor {
        return Colors.gray
    }

    var titleFont: UIFont {
        return Fonts.light(size: 22)!
    }

    var subTitleFont: UIFont {
        return Fonts.semibold(size: 13)!
    }

    var amountFont: UIFont {
        return Fonts.semibold(size: 15)!
    }

    var contentsBackgroundColor: UIColor {
        switch transaction.state {
        case .completed, .error, .unknown, .failed:
            return .white
        case .pending:
            return Colors.veryLightOrange
        }
    }
    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var amountAttributedString: NSAttributedString {
        let value = transactionViewModel.shortValue

        return NSAttributedString(
            string: transactionViewModel.amountWithSign(for: value.amount) + " " + value.symbol,
            attributes: [
                .font: Fonts.light(size: 25)!,
                .foregroundColor: transactionViewModel.amountTextColor,
            ]
        )
    }

    var statusImage: UIImage? {
        switch transaction.state {
        case .error, .unknown, .failed: return R.image.transaction_error()
        case .completed:
            switch transactionViewModel.direction {
            case .incoming: return R.image.transaction_received()
            case .outgoing: return R.image.transaction_sent()
            }
        case .pending:
            return R.image.transaction_pending()
        }
    }
}
