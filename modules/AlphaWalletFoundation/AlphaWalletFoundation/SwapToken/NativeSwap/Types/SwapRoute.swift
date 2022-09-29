//
//  SwapRoute.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 21.09.2022.
//

import Foundation
import BigInt

struct SwapRouteReponse {
    let routes: [SwapRoute]
}

public struct SwapRoute {
    public let id: String
    public let fromToken: SwapQuote.Token
    public let toToken: SwapQuote.Token
    public let steps: [SwapRoute.SwapStep]
    public let tags: [String]
    public let gasCostUsd: String
    public let fromChainId: Int
    public let fromAmount: BigUInt
    public let fromAmountUsd: String
    public let toChainId: Int
    public let toAmount: BigUInt
    public let toAmountUsd: String
    public let toAmountMin: String

    public struct SwapStep {
        public let estimate: SwapEstimate
        public let action: SwapQuote.Action
        public let tool: String
        public let type: String
    }
}

extension SwapRoute.SwapStep: Decodable {
    private enum Keys: String, CodingKey {
        case estimate
        case action
        case tool
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        estimate = try container.decode(SwapEstimate.self, forKey: .estimate)
        action = try container.decode(SwapQuote.Action.self, forKey: .action)
        tool = try container.decode(String.self, forKey: .tool)
        type = try container.decode(String.self, forKey: .type)
    }
}

extension SwapRouteReponse: Decodable {
    private enum Keys: String, CodingKey {
        case routes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        routes = try container.decode([SwapRoute].self, forKey: .routes)
    }
}

extension SwapRoute: Decodable {
    private enum Keys: String, CodingKey {
        case fromToken
        case toToken
        case steps
        case tags
        case gasCostUsd = "gasCostUSD"
        case fromChainId
        case fromAmount
        case fromAmountUsd = "fromAmountUSD"
        case toChainId
        case toAmount
        case toAmountUsd = "toAmountUSD"
        case toAmountMin
        case id
    }
    private struct ParsingError: Error {
        let fieldName: Keys
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)

        fromToken = try container.decode(SwapQuote.Token.self, forKey: .fromToken)
        toToken = try container.decode(SwapQuote.Token.self, forKey: .toToken)
        steps = try container.decode([SwapRoute.SwapStep].self, forKey: .steps)
        tags = try container.decode([String].self, forKey: .tags)
        gasCostUsd = try container.decode(String.self, forKey: .gasCostUsd)
        fromChainId = try container.decode(Int.self, forKey: .fromChainId)
        let fromAmountString = try container.decode(String.self, forKey: .fromAmount)
        fromAmount = try BigUInt(fromAmountString) ?? { throw ParsingError(fieldName: .fromAmount) }()
        fromAmountUsd = try container.decode(String.self, forKey: .fromAmountUsd)
        toChainId = try container.decode(Int.self, forKey: .toChainId)
        let toAmountString = try container.decode(String.self, forKey: .toAmount)
        toAmount = try BigUInt(toAmountString) ?? { throw ParsingError(fieldName: .toAmount) }()
        toAmountUsd = try container.decode(String.self, forKey: .toAmountUsd)
        toAmountMin = try container.decode(String.self, forKey: .toAmountMin)
        id = try container.decode(String.self, forKey: .id)
    }
}
