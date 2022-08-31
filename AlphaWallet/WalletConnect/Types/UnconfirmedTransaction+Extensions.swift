//
//  UnconfirmedTransaction+Extensions.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.10.2020.
//

import Foundation
import BigInt
import AlphaWalletFoundation

extension UnconfirmedTransaction {
    init(transactionType: TransactionType, bridge transaction: RawTransactionBridge) {
        self = .init(
                transactionType: transactionType,
                value: transaction.value ?? BigInt("0"),
                //Tight coupling. Sets recipient and contract relying on implementation of `TransactionConfigurator.toAddress` for `TransactionType.dapp`.
                recipient: nil,
                contract: transaction.to,
                data: transaction.data,
                gasPrice: transaction.gasPrice,
                nonce: transaction.nonce)
    }
}
