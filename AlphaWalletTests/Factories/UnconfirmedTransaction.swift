// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet
import BigInt

extension UnconfirmedTransaction {
    static func make(
        transferType: TransferType = .nativeCryptocurrency(server: .main, destination: .none, amount: nil),
        value: BigInt = BigInt(1),
        to: AlphaWallet.Address = .make(),
        data: Data = Data(),
        gasLimit: BigInt? = BigInt(100000),
        gasPrice: BigInt? = BigInt(1000),
        nonce: BigInt? = BigInt(1)
    ) -> UnconfirmedTransaction {
        return UnconfirmedTransaction(
            transferType: transferType,
            value: value,
            to: to,
            data: data,
            gasLimit: gasLimit,
            tokenId: Constants.nullTokenId,
            gasPrice: gasPrice,
            nonce: nonce,
            v: .none,
            r: .none,
            s: .none,
            expiry: .none,
            indices: .none,
            tokenIds: [BigUInt]()
        )
    }
}
