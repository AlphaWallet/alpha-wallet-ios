//
//  FakeTokenSwapperNetworking.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

@testable import AlphaWallet
import Combine
import BigInt
import AlphaWalletCore
import AlphaWalletFoundation

final class FakeTokenSwapperNetworking: TokenSwapperNetworking {
    func fetchSupportedTools() -> AnyPublisher<[SwapTool], SwapError> {
        return .fail(SwapError.unknownError)
    }

    func fetchSwapRoutes(fromToken: TokenToSwap, toToken: TokenToSwap, slippage: String, fromAmount: BigUInt, exchanges: [String]) -> AnyPublisher<[SwapRoute], SwapError> {
        return .fail(SwapError.unknownError)
    }

    func fetchSwapQuote(fromToken: TokenToSwap, toToken: TokenToSwap, wallet: AlphaWallet.Address, slippage: String, fromAmount: BigUInt, exchange: String) -> AnyPublisher<SwapQuote, SwapError> {
        return .fail(SwapError.unknownError)
    }

    func fetchSupportedChains() -> AnyPublisher<[RPCServer], PromiseError> {
        return .fail(PromiseError.some(error: SwapError.unknownError))
    }

    func fetchSupportedTokens(for server: RPCServer) -> AnyPublisher<SwapPairs, PromiseError> {
        return .fail(PromiseError.some(error: SwapError.unknownError))
    }
    func fetchSwapQuote(fromToken: TokenToSwap, toToken: TokenToSwap, wallet: AlphaWallet.Address, slippage: String, fromAmount: BigUInt) -> AnyPublisher<SwapQuote, SwapError> {
        return .fail(SwapError.unknownError)
    }
}
