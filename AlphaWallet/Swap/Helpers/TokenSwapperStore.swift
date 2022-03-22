//
//  TokenSwapperStore.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.05.2022.
//

import Foundation

protocol TokenSwapperStore {
    mutating func addOrUpdate(servers: [RPCServer])
    func supports(forServer server: RPCServer) -> Bool
    func swapPairs(forServer server: RPCServer) -> SwapPairs?

    mutating func addOrUpdate(swapPairs: SwapPairs, forServer server: RPCServer)
    func containsSwapPairs(forServer server: RPCServer) -> Bool
}

struct InMemoryTokenSwapperStore: TokenSwapperStore {
    private var supportedServers: AtomicArray<RPCServer> = .init()
    private var supportedTokens: AtomicDictionary<RPCServer, SwapPairs> = .init()
    
    mutating func addOrUpdate(servers: [RPCServer]) {
        supportedServers.set(array: servers)
    }

    func supports(forServer server: RPCServer) -> Bool {
        return supportedServers.contains(server)
    }

    func swapPairs(forServer server: RPCServer) -> SwapPairs? {
        return supportedTokens[server]
    }

    func addOrUpdate(swapPairs: SwapPairs, forServer server: RPCServer) {
        self.supportedTokens[server] = swapPairs
    }

    func containsSwapPairs(forServer server: RPCServer) -> Bool {
        swapPairs(forServer: server) != nil
    }
}
