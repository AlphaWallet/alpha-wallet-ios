// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import BigInt
import AlphaWalletFoundation

extension UnconfirmedTransaction {
    static func make(transactionType: TransactionType = .nativeCryptocurrency(Token(), destination: .none, amount: .notSet),
                     value: BigUInt = BigUInt(1),
                     to: AlphaWallet.Address = .make(),
                     recipient: AlphaWallet.Address? = .none,
                     data: Data = Data(),
                     gasLimit: BigUInt? = BigUInt(100000),
                     gasPrice: GasPrice? = .legacy(gasPrice: BigUInt(1000)),
                     nonce: BigUInt? = BigUInt(1)) -> UnconfirmedTransaction {

        return UnconfirmedTransaction(
            transactionType: transactionType,
            value: value,
            recipient: recipient,
            contract: to,
            data: data,
            gasLimit: gasLimit,
            gasPrice: gasPrice,
            nonce: nonce)
    }
}
