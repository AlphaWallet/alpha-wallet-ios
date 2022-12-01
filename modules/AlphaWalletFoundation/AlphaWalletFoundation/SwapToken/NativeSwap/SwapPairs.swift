// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

public struct SwapPairs {
    let connections: Swap.Connections
    let fromTokens: [SwappableToken]

    init(connections: Swap.Connections) {
        self.connections = connections
        self.fromTokens = connections.connections.flatMap { $0.fromTokens }
    }

    func getToTokens(forFromToken fromToken: SwappableToken) -> [SwappableToken] {
        connections.connections.flatMap { connection -> [SwappableToken] in
            if fromToken.server == connection.fromServer, connection.fromTokens.contains(fromToken) {
                return connection.toTokens
            } else {
                return []
            }
        }
    }
}
