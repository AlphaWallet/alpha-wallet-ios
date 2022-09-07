// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import PromiseKit
import web3swift

public class GetBlockTimestamp {
    private static var blockTimestampCache = AtomicDictionary<RPCServer, [BigUInt: Promise<Date>]>()

    public func getBlockTimestamp(_ blockNumber: BigUInt, onServer server: RPCServer) -> Promise<Date> {
        var cacheForServer = Self.blockTimestampCache[server] ?? .init()
        if let datePromise = cacheForServer[blockNumber] {
            return datePromise
        }

        guard let web3 = try? getCachedWeb3(forServer: server, timeout: 6) else {
            return Promise(error: Web3Error(description: "Error creating web3 for: \(server.rpcURL) + \(server.web3Network)"))
        }

        let promise: Promise<Date> = firstly {
            web3swift.web3.Eth(provider: web3.provider, web3: web3).getBlockByNumberPromise(blockNumber)
        }.map(on: web3.requestDispatcher.queue, { $0.timestamp })

        cacheForServer[blockNumber] = promise
        Self.blockTimestampCache[server] = cacheForServer

        return promise
    }
}

