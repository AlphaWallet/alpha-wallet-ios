// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation
import AlphaWalletFoundation

struct TransactionRowCellViewModel {
    private let transactionRow: TransactionRow
    private let wallet: Wallet
    private let transactionRowViewModel: TransactionRowViewModel

    init(transactionRow: TransactionRow, blockNumberProvider: BlockNumberProvider, wallet: Wallet) {
        self.transactionRow = transactionRow
        self.wallet = wallet
        self.transactionRowViewModel = TransactionRowViewModel(transactionRow: transactionRow, blockNumberProvider: blockNumberProvider, wallet: wallet)
    }

    private var operationTitle: String? {
        let operation: LocalizedOperation?
        switch transactionRow {
        case .standalone(let transaction):
            operation = transaction.operation
        case .group:
            operation = nil
        case .item(_, let op):
            operation = op
        }
        if let operation = operation {
            switch operation.operationType {
            case .nativeCurrencyTokenTransfer, .erc20TokenTransfer, .erc721TokenTransfer, .erc875TokenTransfer, .erc1155TokenTransfer:
                return R.string.localizable.transactionCellTokenTransferTitle(operation.symbol ?? "")
            case .erc20TokenApprove:
                return R.string.localizable.transactionCellTokenApproveTitle(operation.symbol ?? "")
            case .erc721TokenApproveAll:
                return R.string.localizable.transactionCellTokenApproveAllTitle(operation.symbol ?? "")
            case .unknown:
                return nil
            }
        } else {
            return nil
        }
    }

    var blockchainTagLabelViewModel: BlockchainTagLabelViewModel {
        return .init(server: transactionRow.server, isHidden: false)
    }

    var title: String {
        if let operationTitle = operationTitle {
            return operationTitle
        }
        switch transactionRow.state {
        case .completed:
            switch transactionRowViewModel.direction {
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
        switch transactionRowViewModel.direction {
        case .incoming: return "\(transactionRow.from)"
        case .outgoing: return "\(transactionRow.to)"
        }
    }

    var contentsBackgroundColor: UIColor {
        switch transactionRow.state {
        case .completed, .error, .unknown, .failed:
            return Configuration.Color.Semantic.defaultViewBackground
        case .pending:
            return Configuration.Color.Semantic.pendingState
        }
    }

    var amountAttributedString: NSAttributedString {
        let value = transactionRowViewModel.shortValue
        let amount: String
        if let operation = transactionRow.operation, (operation.operationType == .erc721TokenTransfer || operation.operationType == .erc875TokenTransfer) {
            amount = transactionRowViewModel.amountWithSign(for: value.amount)
        } else {
            amount = transactionRowViewModel.amountWithSign(for: value.amount) + " " + value.symbol
        }

        return NSAttributedString(string: amount, attributes: [
            .font: Fonts.regular(size: ScreenChecker.size(big: 22, medium: 22, small: 17)),
            .foregroundColor: transactionRowViewModel.amountTextColor,
        ])
    }

    var statusImage: UIImage? {
        switch transactionRow.state {
        case .error, .unknown, .failed: return R.image.transaction_error()
        case .completed: return nil
        case .pending: return R.image.transaction_pending()
        }
    }

    var leftMargin: CGFloat {
        switch transactionRow {
        case .standalone: return DataEntry.Metric.sideMargin
        case .group: return DataEntry.Metric.sideMargin
        case .item: return DataEntry.Metric.sideMargin + ScreenChecker.size(big: 20, medium: 20, small: 10)
        }
    }
}
