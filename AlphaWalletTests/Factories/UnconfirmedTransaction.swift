// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import BigInt
import AlphaWalletFoundation

extension UnconfirmedTransaction {
    static func make(
        transactionType: TransactionType = .nativeCryptocurrency(Token(), destination: .none, amount: nil),
        value: BigInt = BigInt(1),
        to: AlphaWallet.Address = .make(),
        recipient: AlphaWallet.Address? = .none,
        data: Data = Data(),
        gasLimit: BigInt? = BigInt(100000),
        gasPrice: BigInt? = BigInt(1000),
        nonce: BigInt? = BigInt(1)
    ) -> UnconfirmedTransaction {
        return UnconfirmedTransaction(
            transactionType: transactionType,
            value: value,
            recipient: recipient,
            contract: to,
            data: data,
            tokenId: nil,
            gasLimit: gasLimit,
            gasPrice: gasPrice,
            nonce: nonce
        )
    }
}
