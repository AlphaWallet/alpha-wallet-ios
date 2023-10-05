// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import AlphaWalletCore
import BigInt

public struct TokenSelection: Equatable, Hashable {
    public let tokenId: TokenId
    public let value: BigUInt

    public init(tokenId: TokenId, value: BigUInt) {
        self.tokenId = tokenId
        self.value = value
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.tokenId == rhs.tokenId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(tokenId)
        hasher.combine(value)
    }
}
