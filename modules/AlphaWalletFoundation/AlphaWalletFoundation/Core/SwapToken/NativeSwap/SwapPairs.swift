// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

public class SwapPairs {
    public let connections: Swap.Connections

    lazy var fromTokens: [SwappableToken] = connections.connections.flatMap { $0.fromTokens }

    public init(connections: Swap.Connections) {
        self.connections = connections
    }

    public func getToTokens(forFromToken fromToken: SwappableToken) -> [SwappableToken] {
        connections.connections.flatMap { connection -> [SwappableToken] in
            if fromToken.server == connection.fromServer, connection.fromTokens.contains(fromToken) {
                return connection.toTokens
            } else {
                return []
            }
        }
    }
}
