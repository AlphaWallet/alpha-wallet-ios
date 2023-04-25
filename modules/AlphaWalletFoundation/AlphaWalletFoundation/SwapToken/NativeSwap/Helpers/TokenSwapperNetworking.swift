//
//  LiQuestTokenSwapperNetworking.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Foundation
import Combine
import SwiftyJSON
import BigInt
import AlphaWalletCore

public protocol TokenSwapperNetworking {
    func fetchSupportedTools() -> AnyPublisher<[SwapTool], SwapError>
    func fetchSupportedChains() -> AnyPublisher<[RPCServer], PromiseError>
    func fetchSupportedTokens(for server: RPCServer) -> AnyPublisher<SwapPairs, PromiseError>
    func fetchSwapRoutes(fromToken: TokenToSwap, toToken: TokenToSwap, slippage: String, fromAmount: BigUInt, exchanges: [String]) -> AnyPublisher<[SwapRoute], SwapError>
    func fetchSwapQuote(fromToken: TokenToSwap, toToken: TokenToSwap, wallet: AlphaWallet.Address, slippage: String, fromAmount: BigUInt, exchange: String) -> AnyPublisher<SwapQuote, SwapError>
}

public final class LiQuestTokenSwapperNetworking: TokenSwapperNetworking {
    //NOTE: for debug using: testnet URL(string: "https://staging.li.quest")!
    private static let baseUrl = URL(string: "https://li.quest")!
    private let networkService: NetworkService
    private let decoder = JSONDecoder()

    public init(networkService: NetworkService) {
        self.networkService = networkService
    }

    public func fetchSupportedTools() -> AnyPublisher<[SwapTool], SwapError> {
        networkService
            .dataTaskPublisher(ToolsRequest())
            .receive(on: DispatchQueue.global())
            .mapError { SwapError(error: $0.unwrapped) }
            .flatMap { [decoder] data, _ -> AnyPublisher<[SwapTool], SwapError> in
                if let response: SwapToolsResponse = try? decoder.decode(SwapToolsResponse.self, from: data) {
                    return .just(response.tools)
                } else {
                    return .fail(SwapError.invalidJson)
                }
            }.eraseToAnyPublisher()
    }

    public func fetchSwapRoutes(fromToken: TokenToSwap, toToken: TokenToSwap, slippage: String, fromAmount: BigUInt, exchanges: [String]) -> AnyPublisher<[SwapRoute], SwapError> {
        return networkService
            .dataTaskPublisher(RoutesRequest(fromToken: fromToken, toToken: toToken, slippage: slippage, fromAmount: fromAmount, exchanges: exchanges))
            .receive(on: DispatchQueue.global())
            .mapError { SwapError(error: $0.unwrapped) }
            .flatMap { [decoder] data, _ -> AnyPublisher<[SwapRoute], SwapError> in
                if let response: SwapRouteReponse = try? decoder.decode(SwapRouteReponse.self, from: data) {
                    return .just(response.routes)
                } else {
                    return .fail(SwapError.invalidJson)
                }
            }.eraseToAnyPublisher()
    }

    public func fetchSupportedChains() -> AnyPublisher<[RPCServer], PromiseError> {
        return networkService
            .dataTaskPublisher(SupportedChainsRequest())
            .receive(on: DispatchQueue.global())
            .map { data, _ -> [RPCServer] in
                let chains = JSON(data)["chains"].arrayValue
                return chains.compactMap { each in return RPCServer(chainIdOptional: each["id"].intValue) }
            }.mapError { PromiseError(error: $0) }
            .eraseToAnyPublisher()
    }

    public func fetchSupportedTokens(for server: RPCServer) -> AnyPublisher<SwapPairs, PromiseError> {
        return networkService
            .dataTaskPublisher(SupportedTokensRequest(server: server))
            .receive(on: DispatchQueue.global())
            .map { [decoder] data, _ -> SwapPairs in
                if let connections: Swap.Connections = try? decoder.decode(Swap.Connections.self, from: data) {
                    return SwapPairs(connections: connections)
                } else {
                    return SwapPairs(connections: .init(connections: []))
                }
            }.mapError { PromiseError(error: $0) }
            .eraseToAnyPublisher()
    }

    public func fetchSwapQuote(fromToken: TokenToSwap, toToken: TokenToSwap, wallet: AlphaWallet.Address, slippage: String, fromAmount: BigUInt, exchange: String) -> AnyPublisher<SwapQuote, SwapError> {
        return networkService
            .dataTaskPublisher(SwapQuoteRequest(fromToken: fromToken, toToken: toToken, wallet: wallet, slippage: slippage, fromAmount: fromAmount, exchange: exchange))
            .receive(on: DispatchQueue.global())
            .mapError { SwapError(error: $0.unwrapped) }
            .flatMap { [decoder] data, _ -> AnyPublisher<SwapQuote, SwapError> in
                if let swapQuote = try? decoder.decode(SwapQuote.self, from: data) {
                    return .just(swapQuote)
                } else if let error = try? decoder.decode(SwapQuote.Error.self, from: data) {
                    return .fail(SwapError.unableToBuildSwapUnsignedTransaction(message: error.message))
                } else {
                    return .fail(SwapError.unableToBuildSwapUnsignedTransactionFromSwapProvider)
                }
            }.eraseToAnyPublisher()
    }
}

fileprivate extension LiQuestTokenSwapperNetworking {

    struct ToolsRequest: URLRequestConvertible {

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: LiQuestTokenSwapperNetworking.baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/v1/tools"
            return try URLRequest(url: components.asURL(), method: .get)
        }
        
    }

    struct RoutesRequest: URLRequestConvertible {
        let fromToken: TokenToSwap
        let toToken: TokenToSwap
        let slippage: String
        let fromAmount: BigUInt
        let exchanges: [String]
        
        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: LiQuestTokenSwapperNetworking.baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/v1/advanced/routes"
            var request = try URLRequest(url: components.asURL(), method: .post)
            var options: Parameters = ["slippage": slippage.doubleValue]
            if !exchanges.isEmpty {
                options["exchanges"] = exchanges
            }

            return try JSONEncoding().encode(request, with: [
                "options": options,
                "fromChainId": fromToken.server.chainID,
                "toChainId": toToken.server.chainID,
                "fromTokenAddress": fromToken.address.eip55String,
                "toTokenAddress": toToken.address.eip55String,
                "fromAmount": String(fromAmount)
            ]).appending(httpHeaders: ["accept": "application/json"])
        }
    }

    struct SwapQuoteRequest: URLRequestConvertible {
        let fromToken: TokenToSwap
        let toToken: TokenToSwap
        let wallet: AlphaWallet.Address
        let slippage: String
        let fromAmount: BigUInt
        let exchange: String

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: LiQuestTokenSwapperNetworking.baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/v1/quote"
            var request = try URLRequest(url: components.asURL(), method: .get)

            return try URLEncoding().encode(request, with: [
                "fromChain": fromToken.server.chainID,
                "toChain": toToken.server.chainID,
                "fromToken": fromToken.address.eip55String,
                "toToken": toToken.address.eip55String,
                "fromAddress": wallet.eip55String,
                "fromAmount": String(fromAmount),
                //"order": "BEST_VALUE", this param doesn't work for now
                "slippage": slippage,
                //"allowExchanges": "paraswap,openocean,0x,uniswap,sushiswap,quickswap,honeyswap,pancakeswap,spookyswap,viperswap,solarbeam,dodo",
                "allowExchanges": exchange,
            ])
        }
    }

    struct SupportedTokensRequest: URLRequestConvertible {
        let server: RPCServer

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: LiQuestTokenSwapperNetworking.baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/v1/connections"
            var request = try URLRequest(url: components.asURL(), method: .post)

            return try URLEncoding().encode(request, with: [
                "fromChain": server.chainID,
                "toChain": server.chainID,
            ])
        }
    }

    struct SupportedChainsRequest: URLRequestConvertible {
        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: LiQuestTokenSwapperNetworking.baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/v1/chains"
            return try URLRequest(url: components.asURL(), method: .get)
        }
        
    }
}

extension URLRequest {

    public func appending(httpHeaders: [String: String]) -> URLRequest {
        var request = self
        request.allHTTPHeaderFields = (request.allHTTPHeaderFields ?? [:]).merging(httpHeaders) { (_, new) in new }

        return request
    }

    public func curl(pretty: Bool = false) -> String {
        guard let url = url else { return "" }
        var baseCommand = #"curl "\#(url.absoluteString)""#

        if httpMethod == "HEAD" {
            baseCommand += " --head"
        }

        var command = [baseCommand]

        if let method = httpMethod, method != "GET" && method != "HEAD" {
            command.append("-X \(method)")
        }

        if let headers = allHTTPHeaderFields {
            for (key, value) in headers where key != "Cookie" {
                command.append("-H '\(key): \(value)'")
            }
        }

        if let data = httpBody, let body = String(data: data, encoding: .utf8) {
            command.append("-d '\(body)'")
        }

        return command.joined(separator: " \\\n\t")
    }

}
