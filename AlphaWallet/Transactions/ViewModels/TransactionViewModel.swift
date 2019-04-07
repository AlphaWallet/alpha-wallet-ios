// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import BigInt

struct TransactionViewModel {
    private let transaction: Transaction
    private let chainState: ChainState
    private let currentWallet: Wallet
    private let shortFormatter = EtherNumberFormatter.short
    private let fullFormatter = EtherNumberFormatter.full

    private var server: RPCServer {
        return transaction.server
    }

    init(
        transaction: Transaction,
        chainState: ChainState,
        currentWallet: Wallet
    ) {
        self.transaction = transaction
        self.chainState = chainState
        self.currentWallet = currentWallet
    }

    var direction: TransactionDirection {
        if currentWallet.address.description.sameContract(as: transaction.from) {
            return .outgoing
        } else {
            return .incoming
        }
    }

    var confirmations: Int? {
        return chainState.confirmations(fromBlock: transaction.blockNumber)
    }

    var amountTextColor: UIColor {
        switch direction {
        case .incoming: return Colors.green
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
        let amount = NSAttributedString(
            string: amountWithSign(for: value.amount),
            attributes: [
                .font: Fonts.regular(size: 24) as Any,
                .foregroundColor: amountTextColor,
            ]
        )

        let currency = NSAttributedString(
            string: " " + value.symbol,
            attributes: [
                .font: Fonts.regular(size: 16) as Any
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
        if let operation = transaction.operation, let symbol = operation.symbol {
            if operation.operationType == .erc721TokenTransfer || operation.operationType == .erc875TokenTransfer {
                return TransactionValue(
                        amount: operation.value,
                        symbol: symbol
                )
            } else {
                return TransactionValue(
                        amount: formatter.string(from: BigInt(operation.value) ?? BigInt(), decimals: operation.decimals),
                        symbol: symbol
                )
            }
        } else {
            return TransactionValue(
                    amount: formatter.string(from: BigInt(transaction.value) ?? BigInt()),
                    symbol: server.symbol
            )
        }
    }
}
