//
//  TokenSwapperStore.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.05.2022.
//

import Foundation
import AlphaWalletCore

protocol TokenSwapperStore {
    mutating func addOrUpdate(swapSupportStates: [SwapSupportState])
    func supportState(for server: RPCServer) -> SwapSupportState
    func swapPairs(for server: RPCServer) -> SwapPairs?

    mutating func addOrUpdate(swapPairs: SwapPairs, for server: RPCServer)
    func containsSwapPairs(for server: RPCServer) -> Bool
}

struct InMemoryTokenSwapperStore: TokenSwapperStore {
    private var supportedServers: AtomicArray<SwapSupportState> = .init()
    private var supportedTokens: AtomicDictionary<RPCServer, SwapPairs> = .init()
    
    mutating func addOrUpdate(swapSupportStates: [SwapSupportState]) {
        supportedServers.set(array: swapSupportStates)
    }

    func supportState(for server: RPCServer) -> SwapSupportState {
        switch supportedServers.first(where: { $0.server == server }) {
        case .some(let value):
            return value
        case .none:
            return .init(server: server, supportingType: .notSupports)
        }
    }

    func swapPairs(for server: RPCServer) -> SwapPairs? {
        return supportedTokens[server]
    }

    func addOrUpdate(swapPairs: SwapPairs, for server: RPCServer) {
        self.supportedTokens[server] = swapPairs
    }

    func containsSwapPairs(for server: RPCServer) -> Bool {
        swapPairs(for: server) != nil
    }
}
