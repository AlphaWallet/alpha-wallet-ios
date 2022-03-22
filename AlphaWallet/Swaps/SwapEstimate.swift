// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import BigInt

struct SwapEstimate: Decodable {
    private enum Keys: String, CodingKey {
        case approvalAddress
        case toAmount
        case toAmountMin
    }

    private struct ParsingError: Error {
        let fieldName: Keys
    }

    let spender: AlphaWallet.Address
    let toAmount: BigUInt
    let toAmountMin: BigUInt

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)

        let spenderString = try container.decode(String.self, forKey: .approvalAddress)
        spender = try AlphaWallet.Address(string: spenderString) ?? { throw ParsingError(fieldName: .approvalAddress) }()
        let toAmountString = try container.decode(String.self, forKey: .toAmount)
        toAmount = try BigUInt(toAmountString) ?? { throw ParsingError(fieldName: .toAmount) }()
        let toAmountMinString = try container.decode(String.self, forKey: .toAmountMin)
        toAmountMin = try BigUInt(toAmountMinString) ?? { throw ParsingError(fieldName: .toAmountMin) }()
    }
}