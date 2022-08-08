//
//  FakeTokenSwapper.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

@testable import AlphaWallet
import Combine
import BigInt
import AlphaWalletCore

final class FakeTokenSwapperNetworkProvider: TokenSwapperNetworkProvider {
    func fetchSupportedChains() -> AnyPublisher<[RPCServer], PromiseError> {
        return Just<[RPCServer]>([])
            .setFailureType(to: PromiseError.self)
            .eraseToAnyPublisher()
    }

    func fetchSupportedTokens(forServer server: RPCServer) -> AnyPublisher<SwapPairs, PromiseError> {
        return Just<SwapPairs>(.init(connections: .init(connections: [])))
            .setFailureType(to: PromiseError.self)
            .eraseToAnyPublisher()
    }
    func fetchSwapQuote(fromToken: TokenToSwap, toToken: TokenToSwap, wallet: AlphaWallet.Address, slippage: Double, fromAmount: BigUInt) -> AnyPublisher<SwapQuote, SwapError> {
        return Fail(error: SwapError.unknownError)
            .eraseToAnyPublisher()
    }
}
