//
//  LiQuestTokenSwapperNetworkProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Foundation
import Combine
import SwiftyJSON
import Alamofire
import BigInt
import AlphaWalletCore

public protocol TokenSwapperNetworkProvider {
    func fetchSupportedChains() -> AnyPublisher<[RPCServer], PromiseError>
    func fetchSupportedTokens(for server: RPCServer) -> AnyPublisher<SwapPairs, PromiseError>
    func fetchSwapQuote(fromToken: TokenToSwap, toToken: TokenToSwap, wallet: AlphaWallet.Address, slippage: String, fromAmount: BigUInt) -> AnyPublisher<SwapQuote, SwapError>
}

public final class LiQuestTokenSwapperNetworkProvider: TokenSwapperNetworkProvider {
    struct Url {
        static let fetchQuote = URL(string: "https://li.quest/v1/quote")!
        static let fetchAvailableTokenConnections = URL(string: "https://li.quest/v1/connections")!
        static let fetchSupportedChains = URL(string: "https://li.quest/v1/chains")!
    }
    public init() {}

    public func fetchSupportedChains() -> AnyPublisher<[RPCServer], PromiseError> {
        return Alamofire.request(LiQuestTokenSwapperNetworkProvider.Url.fetchSupportedChains).validate()
            .responseJSONPublisher()
            .map { rawJson, _ -> [RPCServer] in
                let chains = JSON(rawJson)["chains"].arrayValue
                return chains.compactMap { each in return RPCServer(chainIdOptional: each["id"].intValue) }
            }.eraseToAnyPublisher()
    }

    public func fetchSupportedTokens(for server: RPCServer) -> AnyPublisher<SwapPairs, PromiseError> {
        let parameters: [String: Any] = [
            "fromChain": server.chainID,
            "toChain": server.chainID,
        ]
        return Alamofire.request(LiQuestTokenSwapperNetworkProvider.Url.fetchAvailableTokenConnections, method: .post, parameters: parameters)
            .responseDataPublisher()
            .map { jsonData, _ -> SwapPairs in
                if let connections: Swap.Connections = try? JSONDecoder().decode(Swap.Connections.self, from: jsonData) {
                    return SwapPairs(connections: connections)
                } else {
                    return SwapPairs(connections: .init(connections: []))
                }
            }.eraseToAnyPublisher()
    }

    public func fetchSwapQuote(fromToken: TokenToSwap, toToken: TokenToSwap, wallet: AlphaWallet.Address, slippage: String, fromAmount: BigUInt) -> AnyPublisher<SwapQuote, SwapError> {
        let parameters: [String: Any] = [
            "fromChain": fromToken.server.chainID,
            "toChain": toToken.server.chainID,
            "fromToken": fromToken.address.eip55String,
            "toToken": toToken.address.eip55String,
            "fromAddress": wallet.eip55String,
            "fromAmount": String(fromAmount),
            //"order": "BEST_VALUE", this param doesn't work for now
            "slippage": slippage,
            //"allowExchanges": "paraswap,openocean,0x,uniswap,sushiswap,quickswap,honeyswap,pancakeswap,spookyswap,viperswap,solarbeam,dodo",
            //"allowExchanges": "paraswap",
        ]

        return Alamofire.request(LiQuestTokenSwapperNetworkProvider.Url.fetchQuote, parameters: parameters)
            .responseJSONPublisher()
            .tryMap { rawJson, _ -> SwapQuote in
                guard let data = try? JSONSerialization.data(withJSONObject: rawJson) else { throw SwapError.invalidJson }
                if let swapQuote = try? JSONDecoder().decode(SwapQuote.self, from: data) {
                    return swapQuote
                } else if let error = try? JSONDecoder().decode(SwapQuote.Error.self, from: data) {
                    throw SwapError.unableToBuildSwapUnsignedTransaction(message: error.message)
                } else {
                    throw SwapError.unableToBuildSwapUnsignedTransactionFromSwapProvider
                }
            }.mapError { e in
                if let error = e as? SwapError {
                    return error
                } else {
                    return SwapError.unknownError
                }
            }.eraseToAnyPublisher()
    }
}
