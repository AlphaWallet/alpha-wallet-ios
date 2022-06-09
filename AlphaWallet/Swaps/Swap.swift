// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

enum Swap {
    struct Connection: Decodable {
        private enum Keys: String, CodingKey {
            case fromTokens
            case toTokens
            case fromChainId
            case toChainId
        }

        let fromTokens: [SwappableToken]
        let toTokens: [SwappableToken]
        let fromServer: RPCServer
        let toServer: RPCServer

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Keys.self)

            let fromChainId = try container.decode(Int.self, forKey: .fromChainId)
            let toChainId = try container.decode(Int.self, forKey: .toChainId)
            fromServer = RPCServer(chainID: fromChainId)
            toServer = RPCServer(chainID: toChainId)
            fromTokens = try container.decode([SwappableToken].self, forKey: .fromTokens)
            toTokens = try container.decode([SwappableToken].self, forKey: .toTokens)
        }
    }

    struct Connections: Decodable {
        let connections: [Connection]
    }
}
