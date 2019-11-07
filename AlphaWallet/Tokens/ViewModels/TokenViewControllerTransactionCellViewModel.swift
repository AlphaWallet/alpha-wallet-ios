// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct TokenViewControllerTransactionCellViewModel {
    private let transaction: Transaction
    private let transactionViewModel: TransactionViewModel

    init(
            transaction: Transaction,
            config: Config,
            chainState: ChainState,
            currentWallet: Wallet
    ) {
        self.transaction = transaction
        self.transactionViewModel = TransactionViewModel(
                transaction: transaction,
                chainState: chainState,
                currentWallet: currentWallet
        )
    }

    var date: String {
        return transaction.date.formatAsShortDateString()
    }

    var value: NSAttributedString {
        let value = transactionViewModel.shortValue
        let amount: String
        if let operation = transaction.operation, (operation.operationType == .erc721TokenTransfer || operation.operationType == .erc875TokenTransfer) {
            amount = transactionViewModel.amountWithSign(for: value.amount)
        } else {
            amount = transactionViewModel.amountWithSign(for: value.amount) + " " + value.symbol
        }
        return NSAttributedString(
                string: amount,
                attributes: [
                    .font: Fonts.semibold(size: 17)!,
                    .foregroundColor: transactionViewModel.amountTextColor,
                ]
        )
    }

    var type: String {
        if transaction.state == .pending {
            return R.string.localizable.transactionCellPendingTitle()
        } else {
            switch transactionViewModel.direction {
            case .incoming:
                return R.string.localizable.transactionCellReceivedTitle()
            case .outgoing:
                return R.string.localizable.transactionCellSentTitle()
            }
        }
    }

    var typeImage: UIImage? {
        if transaction.state == .pending {
            return R.image.pending()
        } else {
            switch transactionViewModel.direction {
            case .incoming:
                return R.image.received()
            case .outgoing:
                return R.image.sent()
            }
        }
    }

    var accessoryImage: UIImage? {
        return R.image.transactionAccessory()
    }

    var dateColor: UIColor {
        return Colors.appSubtitle
    }

    var dateFont: UIFont? {
        return Fonts.regular(size: 13)
    }

    var typeColor: UIColor {
        return .init(red: 24, green: 24, blue: 24)
    }

    var typeFont: UIFont? {
        return Fonts.regular(size: 17)
    }
}
