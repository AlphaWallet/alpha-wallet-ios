// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

struct SwapQuote: Decodable {
    private enum Keys: String, CodingKey {
        case transactionRequest
        case estimate
    }

    let unsignedSwapTransaction: UnsignedSwapTransaction
    let estimate: SwapEstimate

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)

        unsignedSwapTransaction = try container.decode(UnsignedSwapTransaction.self, forKey: .transactionRequest)
        estimate = try container.decode(SwapEstimate.self, forKey: .estimate)
    }
}