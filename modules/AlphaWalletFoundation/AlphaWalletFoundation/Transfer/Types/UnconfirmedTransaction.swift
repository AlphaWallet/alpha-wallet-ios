// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

public struct UnconfirmedTransaction {
    public let transactionType: TransactionType
    public let value: BigUInt
    public let recipient: AlphaWallet.Address?
    public let contract: AlphaWallet.Address?
    public let data: Data?
    public let gasLimit: BigUInt?
    public let gasPrice: BigUInt?
    public let nonce: BigUInt?

    public init(
        transactionType: TransactionType,
        value: BigUInt,
        recipient: AlphaWallet.Address?,
        contract: AlphaWallet.Address?,
        data: Data?,
        gasLimit: BigUInt? = nil,
        gasPrice: BigUInt? = nil,
        nonce: BigUInt? = nil) {
        self.transactionType = transactionType
        self.value = value
        self.recipient = recipient
        self.contract = contract
        self.data = data
        self.gasLimit = gasLimit
        self.gasPrice = gasPrice
        self.nonce = nonce
    }
}

extension UnconfirmedTransaction {
    public init(transactionType: TransactionType, walletConnectTransaction transaction: WalletConnectTransaction) {
        self = .init(
            transactionType: transactionType,
            value: transaction.value ?? BigUInt("0"),
            //Tight coupling. Sets recipient and contract relying on implementation of `TransactionConfigurator.toAddress` for `TransactionType.dapp`.
            recipient: nil,
            contract: transaction.to,
            data: transaction.data,
            gasPrice: transaction.gasPrice,
            nonce: transaction.nonce)
    }
}

