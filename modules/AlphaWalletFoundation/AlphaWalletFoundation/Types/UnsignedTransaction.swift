// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

public struct UnsignedTransaction {
    public let value: BigUInt
    public let account: AlphaWallet.Address
    public let to: AlphaWallet.Address?
    public let nonce: Int
    public let data: Data
    public let gasPrice: GasPrice
    public let gasLimit: BigUInt
    public let server: RPCServer
    public let transactionType: TransactionType

    public init(value: BigUInt,
                account: AlphaWallet.Address,
                to: AlphaWallet.Address?,
                nonce: Int,
                data: Data,
                gasPrice: GasPrice,
                gasLimit: BigUInt,
                server: RPCServer,
                transactionType: TransactionType) {

        self.value = value
        self.account = account
        self.to = to
        self.nonce = nonce
        self.data = data
        self.gasPrice = gasPrice
        self.gasLimit = gasLimit
        self.server = server
        self.transactionType = transactionType
    }

    public func updating(nonce: Int) -> UnsignedTransaction {
        return UnsignedTransaction(
            value: value,
            account: account,
            to: to,
            nonce: nonce,
            data: data,
            gasPrice: gasPrice,
            gasLimit: gasLimit,
            server: server,
            transactionType: transactionType)
    }

}
