// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import BigInt
import AlphaWalletFoundation

struct TransactionViewModel {
    let transactionRow: TransactionRow
    private let blockNumberProvider: BlockNumberProvider
    private let wallet: Wallet
    private let fullFormatter = EtherNumberFormatter.full

    var server: RPCServer {
        return transactionRow.server
    }

    init(transactionRow: TransactionRow, blockNumberProvider: BlockNumberProvider, wallet: Wallet) {
        self.transactionRow = transactionRow
        self.blockNumberProvider = blockNumberProvider
        self.wallet = wallet
    }

    var direction: TransactionDirection {
        if wallet.address.sameContract(as: transactionRow.from) {
            return .outgoing
        } else {
            return .incoming
        }
    }

    var confirmations: Int? {
        return blockNumberProvider.confirmations(fromBlock: transactionRow.blockNumber)
    }

    var amountTextColor: UIColor {
        switch direction {
        case .incoming: return Colors.appHighlightGreen
        case .outgoing: return Colors.appRed
        }
    }

    var fullValue: TransactionValue {
        return transactionValue(for: fullFormatter)
    }

    var fullAmountAttributedString: NSAttributedString {
        return amountAttributedString(for: fullValue)
    }

    func amountAttributedString(for value: TransactionValue) -> NSAttributedString {
        let amount = NSAttributedString(string: amountWithSign(for: value.amount), attributes: [
            .font: Fonts.regular(size: 24) as Any,
            .foregroundColor: amountTextColor,
        ])

        let currency = NSAttributedString(string: " " + value.symbol, attributes: [
            .font: Fonts.regular(size: 16) as Any
        ])

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
        case .item(let transaction, let operation):
            if let symbol = operation.symbol {
                if operation.operationType == .erc721TokenTransfer || operation.operationType == .erc875TokenTransfer {
                    return TransactionValue(amount: operation.value, symbol: symbol)
                } else {
                    return TransactionValue(amount: formatter.string(from: BigInt(operation.value) ?? BigInt(), decimals: operation.decimals), symbol: symbol)
                }
            } else {
                return TransactionValue(amount: formatter.string(from: BigInt(transaction.value) ?? BigInt()), symbol: server.symbol)
            }
        }
    }
}
