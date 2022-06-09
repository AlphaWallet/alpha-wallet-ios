// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

class SwapPairs {
    let connections: Swap.Connections

    lazy var fromTokens: [SwappableToken] = connections.connections.flatMap { $0.fromTokens }

    init(connections: Swap.Connections) {
        self.connections = connections
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
