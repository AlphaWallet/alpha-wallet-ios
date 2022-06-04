//
//  FakeTokenSwapper.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

@testable import AlphaWallet
import Combine
import BigInt

final class FakeTokenSwapperNetworkProvider: TokenSwapperNetworkProvider {
    func fetchSupportedChains() -> AnyPublisher<[RPCServer], DataRequestError> {
        return Just<[RPCServer]>([])
            .setFailureType(to: DataRequestError.self)
            .eraseToAnyPublisher()
    }

    func fetchSupportedTokens(forServer server: RPCServer) -> AnyPublisher<SwapPairs, DataRequestError> {
        return Just<SwapPairs>(.init(connections: .init(connections: [])))
            .setFailureType(to: DataRequestError.self)
            .eraseToAnyPublisher()
    }
    func fetchSwapQuote(fromToken: TokenToSwap, toToken: TokenToSwap, wallet: AlphaWallet.Address, slippage: Double, fromAmount: BigUInt) -> AnyPublisher<SwapQuote, SwapError> {
        return Fail(error: SwapError.unknownError)
            .eraseToAnyPublisher()
    }
}
