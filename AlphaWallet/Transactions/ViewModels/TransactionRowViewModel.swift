// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import AlphaWalletFoundation

struct TransactionRowViewModel {
    private let transactionRow: TransactionRow
    private let blockNumberProvider: BlockNumberProvider
    private let wallet: Wallet
    private let shortFormatter = EtherNumberFormatter.short
    private let fullFormatter = EtherNumberFormatter.full

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
        case .incoming: return Configuration.Color.Semantic.appreciation
        case .outgoing: return Configuration.Color.Semantic.depreciation
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

    private func amountAttributedString(for value: TransactionValue) -> NSAttributedString {
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
        if let operation = transactionRow.operation, let symbol = operation.symbol {
            if operation.operationType == .erc721TokenTransfer || operation.operationType == .erc875TokenTransfer {
                return TransactionValue(amount: operation.value, symbol: symbol)
            } else {
                let amount = formatter.string(from: BigInt(operation.value) ?? BigInt(), decimals: operation.decimals)
                return TransactionValue(amount: amount, symbol: symbol)
            }
        } else {
            let amount = formatter.string(from: BigInt(transactionRow.value) ?? BigInt())
            return TransactionValue(amount: amount, symbol: transactionRow.server.symbol)
        }
    }
}
