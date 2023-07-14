// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import AlphaWalletWeb3
import BigInt

public struct UnconfirmedTransaction {
    public let transactionType: TransactionType
    public let value: BigUInt
    public let recipient: AlphaWallet.Address?
    public let contract: AlphaWallet.Address?
    public let data: Data
    public let gasLimit: BigUInt?
    public let gasPrice: GasPrice?
    public let nonce: BigUInt?

    public init(transactionType: TransactionType,
                value: BigUInt,
                recipient: AlphaWallet.Address?,
                contract: AlphaWallet.Address?,
                data: Data = Data(),
                gasLimit: BigUInt? = nil,
                gasPrice: GasPrice? = nil,
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
