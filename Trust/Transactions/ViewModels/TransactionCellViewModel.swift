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
            return R.string.localizable.transactionCellTokenTransferTitle(operation.symbol ?? "")
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
            case .incoming: return R.string.localizable.transactionCellReceivedTitle()
            case .outgoing: return R.string.localizable.transactionCellSentTitle()
            }
        case .error:
            return R.string.localizable.transactionCellErrorTitle()
        case .failed:
            return R.string.localizable.transactionCellFailedTitle()
        case .unknown:
            return R.string.localizable.transactionCellUnknownTitle()
        case .pending:
            return R.string.localizable.transactionCellPendingTitle()
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
