// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import BigInt

struct TransactionViewModel {
    private let transactionRow: TransactionRow
    private let chainState: ChainState
    private let currentWallet: Wallet
    private let shortFormatter = EtherNumberFormatter.short
    private let fullFormatter = EtherNumberFormatter.full

    private var server: RPCServer {
        return transactionRow.server
    }

    init(transactionRow: TransactionRow, chainState: ChainState, currentWallet: Wallet) {
        self.transactionRow = transactionRow
        self.chainState = chainState
        self.currentWallet = currentWallet
    }

    var direction: TransactionDirection {
        if currentWallet.address.sameContract(as: transactionRow.from) {
            return .outgoing
        } else {
            return .incoming
        }
    }

    var confirmations: Int? {
        return chainState.confirmations(fromBlock: transactionRow.blockNumber)
    }

    var amountTextColor: UIColor {
        switch direction {
        case .incoming: return Colors.appHighlightGreen
        case .outgoing: return Colors.appRed
        }
    }

    var shortValue: TransactionValue {
        return transactionValue(for: shortFormatter)
    }

    var fullValue: TransactionValue {
        return transactionValue(for: fullFormatter)
    }

    var fullAmountAttributedString: NSAttributedString {
        return amountAttributedString(for: fullValue)
    }

    func amountAttributedString(for value: TransactionValue) -> NSAttributedString {
        
        //let status = direction == .incoming ? R.string.localizable.receive : R.string.localizable.send
        let amount = NSAttributedString(
            string: amountWithSign(for: value.amount),
            attributes: [
                .font: Fonts.bold(size: 10) as Any,
                .foregroundColor: Colors.headerThemeColor,
            ]
        )

        let currency = NSAttributedString(
            string: " " + value.symbol,
            attributes: [
                .font: Fonts.bold(size: 10) as Any,
                .foregroundColor: Colors.headerThemeColor,
            ]
        )

        return amount + currency
    }

    func amountWithSign(for amount: String) -> String {
        guard amount != "0" else { return amount }
        switch direction {
        case .incoming: return "+\(amount)"
        case .outgoing: return "-\(amount)"
        }
    }

    private func transactionValue(for formatter: EtherNumberFormatter) -> TransactionValue {
        switch transactionRow {
        case .standalone(let transaction):
            if let operation = transaction.operation {
                return TransactionValue(amount: formatter.string(from: BigInt(operation.value) ?? BigInt(), decimals: operation.decimals), symbol: operation.symbol ?? server.symbol)
            } else {
                return TransactionValue(amount: formatter.string(from: BigInt(transaction.value) ?? BigInt()), symbol: server.symbol)
            }
        case .group(let transaction):
            return TransactionValue(amount: formatter.string(from: BigInt(transaction.value) ?? BigInt()), symbol: server.symbol)
        case .item(transaction: let transaction, operation: let operation):
            if let symbol = operation.symbol {
                if operation.operationType == .erc721TokenTransfer || operation.operationType == .erc875TokenTransfer {
                    return TransactionValue(
                            amount: operation.value,
                            symbol: symbol
                    )
                } else {
                    return TransactionValue(amount: formatter.string(from: BigInt(operation.value) ?? BigInt(), decimals: operation.decimals), symbol: symbol)
                }
            } else {
                return TransactionValue(amount: formatter.string(from: BigInt(transaction.value) ?? BigInt()), symbol: server.symbol)
            }
        }
    }
}
