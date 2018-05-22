// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import TrustKeystore

struct UnconfirmedTransaction {
    let transferType: TransferType
    let value: BigInt
    let to: Address?
    let data: Data?
    let gasLimit: BigInt?
    let gasPrice: BigInt?
    let nonce: BigInt?
    // these are not the v, r, s value of a signed transaction
    // but are the v, r, s value of a signed ERC875 order
    // TODO: encapsulate it in the data field
    let v: UInt8?
    let r: String?
    let s: String?
    let expiry: BigUInt?
    let indices: [UInt16]?
}
