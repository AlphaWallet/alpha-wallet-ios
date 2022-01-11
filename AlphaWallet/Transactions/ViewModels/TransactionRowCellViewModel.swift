// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation
import UIKit

struct TransactionRowCellViewModel {
    private let transactionRow: TransactionRow
    private let chainState: ChainState
    private let currentWallet: Wallet
    private let transactionRowViewModel: TransactionRowViewModel
    private let server: RPCServer

    init(
            transactionRow: TransactionRow,
            chainState: ChainState,
            currentWallet: Wallet,
            server: RPCServer
    ) {
        self.transactionRow = transactionRow
        self.chainState = chainState
        self.currentWallet = currentWallet
        self.server = server
        self.transactionRowViewModel = TransactionRowViewModel(
            transactionRow: transactionRow,
            chainState: chainState,
            currentWallet: currentWallet
        )
    }

    private var operationTitle: String? {
        let operation: LocalizedOperationObjectInstance?
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
            case .unknown:
                return nil
            }
        } else {
            return nil
        }
    }

    var titleTextColor: UIColor {
        return Colors.appText
    }

    var title: String {
        if let operationTitle = operationTitle {
            return operationTitle
        }
        switch transactionRow.state {
        case .completed:
            switch transactionRowViewModel.direction {
            case .incoming: return R.string.localizable.transactionCellReceivedTitle(preferredLanguages: Languages.preferred())
            case .outgoing: return R.string.localizable.transactionCellSentTitle(preferredLanguages: Languages.preferred())
            }
        case .error:
            return R.string.localizable.transactionCellErrorTitle(preferredLanguages: Languages.preferred())
        case .failed:
            return R.string.localizable.transactionCellFailedTitle(preferredLanguages: Languages.preferred())
        case .unknown:
            return R.string.localizable.transactionCellUnknownTitle(preferredLanguages: Languages.preferred())
        case .pending:
            return R.string.localizable.transactionCellPendingTitle(preferredLanguages: Languages.preferred())
        }
    }

    var subTitle: String {
        switch transactionRowViewModel.direction {
        case .incoming: return "\(transactionRow.from)"
        case .outgoing: return "\(transactionRow.to)"
        }
    }

    var subTitleTextColor: UIColor {
        return Colors.appSubtitle
    }

    var titleFont: UIFont {
        return Fonts.regular(size: 17)
    }

    var subTitleFont: UIFont {
        return Fonts.regular(size: 13)
    }

    var amountFont: UIFont {
        return Fonts.semibold(size: 14)
    }

    var contentsBackgroundColor: UIColor {
        switch transactionRow.state {
        case .completed, .error, .unknown, .failed:
            return .white
        case .pending:
            return Colors.veryLightOrange
        }
    }

    var contentsCornerRadius: CGFloat {
        return Metrics.CornerRadius.box
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var amountAttributedString: NSAttributedString {
        let value = transactionRowViewModel.shortValue
        let amount: String
        if let operation = transactionRow.operation, (operation.operationType == .erc721TokenTransfer || operation.operationType == .erc875TokenTransfer) {
            amount = transactionRowViewModel.amountWithSign(for: value.amount)
        } else {
            amount = transactionRowViewModel.amountWithSign(for: value.amount) + " " + value.symbol
        }
        return NSAttributedString(
                string: amount,
                attributes: [
                    .font: Fonts.light(size: 25),
                    .foregroundColor: transactionRowViewModel.amountTextColor,
                ]
        )
    }

    var statusImage: UIImage? {
        switch transactionRow.state {
        case .error, .unknown, .failed: return R.image.transaction_error()
        case .completed:
            switch transactionRowViewModel.direction {
            case .incoming: return R.image.received()
            case .outgoing: return R.image.sent()
            }
        case .pending:
            return R.image.transaction_pending()
        }
    }

    var blockChainNameFont: UIFont {
        return Screen.TokenCard.Font.blockChainName
    }

    var blockChainNameColor: UIColor {
        return Screen.TokenCard.Color.blockChainName
    }

    var blockChainNameBackgroundColor: UIColor {
        return server.blockChainNameColor
    }

    var blockChainName: String {
        return "  \(server.name)     "
    }

    var blockChainNameTextAlignment: NSTextAlignment {
        return .center
    }

    var blockChainNameCornerRadius: CGFloat {
        return Screen.TokenCard.Metric.blockChainTagCornerRadius
    }

    var leftMargin: CGFloat {
        switch transactionRow {
        case .standalone:
            return StyleLayout.sideMargin
        case .group:
            return StyleLayout.sideMargin
        case .item:
            return StyleLayout.sideMargin + 20
        }
    }
}
