// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation
import UIKit

struct TransactionCellViewModel {
    private let transaction: Transaction
    private let chainState: ChainState
    private let currentWallet: Wallet
    private let transactionViewModel: TransactionViewModel
    private let server: RPCServer

    init(
        transaction: Transaction,
        chainState: ChainState,
        currentWallet: Wallet,
        server: RPCServer
    ) {
        self.transaction = transaction
        self.chainState = chainState
        self.currentWallet = currentWallet
        self.server = server
        self.transactionViewModel = TransactionViewModel(
            transaction: transaction,
            chainState: chainState,
            currentWallet: currentWallet
        )
    }

    private var operationTitle: String? {
        guard let operation = transaction.operation else { return .none }
        switch operation.operationType {
        case .nativeCurrencyTokenTransfer, .erc20TokenTransfer, .erc721TokenTransfer, .erc875TokenTransfer:
            return R.string.localizable.transactionCellTokenTransferTitle(operation.symbol ?? "")
        case .unknown:
            return .none
        }
    }

    var titleTextColor: UIColor {
        return Colors.appText
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
        return Colors.appSubtitle
    }

    var titleFont: UIFont {
        return Fonts.regular(size: 17)!
    }

    var subTitleFont: UIFont {
        return Fonts.regular(size: 13)!
    }

    var amountFont: UIFont {
        return Fonts.semibold(size: 14)!
    }

    var contentsBackgroundColor: UIColor {
        switch transaction.state {
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
}
