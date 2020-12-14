//
//  UnconfirmedTransaction+Extensions.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.10.2020.
//

import Foundation
import BigInt

extension UnconfirmedTransaction {

    init(transactionType: TransactionType, bridge transaction: RawTransactionBridge) {
        self.transactionType = transactionType
        value = transaction.value ?? BigInt("0")
        recipient = transaction.to 
        data = transaction.data
        gasLimit = .none
        tokenId = .none
        gasPrice = transaction.gasPrice
        nonce = transaction.nonce
        v = .none
        r = .none
        s = .none
        expiry = .none
        indices = .none
    }
}
