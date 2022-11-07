// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

public struct UnconfirmedTransaction {
    public let transactionType: TransactionType
    public let value: BigInt
    public let recipient: AlphaWallet.Address?
    public let contract: AlphaWallet.Address?
    public let data: Data?
    public let gasLimit: BigInt?
    public let gasPrice: BigInt?
    public let nonce: BigInt?

    public init(
        transactionType: TransactionType,
        value: BigInt,
        recipient: AlphaWallet.Address?,
        contract: AlphaWallet.Address?,
        data: Data?,
        gasLimit: BigInt? = nil,
        gasPrice: BigInt? = nil,
        nonce: BigInt? = nil
    ) {
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
