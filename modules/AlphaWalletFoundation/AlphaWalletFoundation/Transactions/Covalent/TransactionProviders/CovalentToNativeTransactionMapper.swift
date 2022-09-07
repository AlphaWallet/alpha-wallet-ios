//
//  CovalentToNativeTransactionMapper.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2022.
//

import Foundation
import BigInt

extension Covalent {
    struct ToNativeTransactionMapper {

        private static let formatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"

            return dateFormatter
        }()

        func mapToNativeTransactions(transactions: [Covalent.Transaction], server: RPCServer) -> [TransactionInstance] {
            transactions.compactMap { covalentTxToNativeTx(tx: $0, server: server) }
        }

        private func covalentTxToNativeTx(tx: Covalent.Transaction, server: RPCServer) -> TransactionInstance? {
            let gas = tx.gasOffered.flatMap { String($0) } ?? ""
            let gasPrice = tx.gasPrice.flatMap { String($0) } ?? ""
            let gasSpent = tx.gasSpent.flatMap { String($0) } ?? ""

            guard let date = ToNativeTransactionMapper.formatter.date(from: tx.blockSignedAt) else {
                return nil
            }

            let operations: [LocalizedOperationObjectInstance] = tx
                .logEvents
                .compactMap { logEvent -> LocalizedOperationObjectInstance? in
                    guard let contractAddress = AlphaWallet.Address(uncheckedAgainstNullAddress: logEvent.senderAddress) else { return nil }
                    var params = logEvent.params
                    //TODO: Improve with adding more transaction types, approve and other
                    guard let from = AlphaWallet.Address(uncheckedAgainstNullAddress: params["from"]?.value ?? "") else { return nil }
                    guard let to = AlphaWallet.Address(uncheckedAgainstNullAddress: params["to"]?.value ?? "") else { return nil }
                    let tokenId = logEvent.senderContractDecimals == 0 ? (params["tokenId"]?.value ?? "") : ""

                    params.removeValue(forKey: "from")
                    params.removeValue(forKey: "to")

                    let value = params["value"]?.value

                    let operationType: OperationType
                    //TODO check have tokenID + no "value", cos those might be ERC1155?
                    if tokenId.nonEmpty {
                        operationType = .erc721TokenTransfer
                    } else {
                        operationType = .erc20TokenTransfer
                    }

                    return .init(from: from.eip55String, to: to.eip55String, contract: contractAddress, type: operationType.rawValue, value: value ?? "", tokenId: tokenId, symbol: logEvent.senderContractTickerSymbol, name: logEvent.senderName, decimals: logEvent.senderContractDecimals)
                }

            let transactionIndex = tx.logEvents.first?.txOffset ?? 0

            return TransactionInstance(id: tx.txHash, server: server, blockNumber: tx.blockHeight, transactionIndex: transactionIndex, from: tx.from, to: tx.to, value: tx.value, gas: gas, gasPrice: gasPrice, gasUsed: gasSpent, nonce: "0", date: date, localizedOperations: operations, state: .completed, isErc20Interaction: true)
        }
    }
}
