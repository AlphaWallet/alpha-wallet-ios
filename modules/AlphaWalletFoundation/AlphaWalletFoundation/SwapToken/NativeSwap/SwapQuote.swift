// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

public struct SwapQuote {
    public let unsignedSwapTransaction: UnsignedSwapTransaction
    public let estimate: SwapEstimate
    public let action: SwapQuote.Action
    public let steps: [SwapEstimate.SwapStep]
    public let tool: String
    public let type: String

    public struct Action {
        public let fromToken: SwapQuote.Token
        public let toToken: SwapQuote.Token
    }

    public struct Token {
        public let address: AlphaWallet.Address
        public let chainId: Int
        public let coinKey: String
        public let decimals: Int
        public let logoURI: String?
        public let name: String
        public let priceUSD: String
        public let symbol: String
    }

    public struct Error {
        public let message: String
    }
}

extension SwapQuote.Error: Decodable {
    private enum Keys: String, CodingKey {
        case message
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        message = try container.decode(String.self, forKey: .message)
    }
}

extension SwapQuote: Decodable {
    private enum Keys: String, CodingKey {
        case transactionRequest
        case estimate
        case action
        case steps = "includedSteps"
        case tool
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)

        unsignedSwapTransaction = try container.decode(UnsignedSwapTransaction.self, forKey: .transactionRequest)
        estimate = try container.decode(SwapEstimate.self, forKey: .estimate)
        action = try container.decode(SwapQuote.Action.self, forKey: .action)
        steps = try container.decode([SwapEstimate.SwapStep].self, forKey: .steps)
        tool = try container.decode(String.self, forKey: .tool)
        type = try container.decode(String.self, forKey: .type)
    }
}

extension SwapQuote.Action: Decodable {
    private enum Keys: String, CodingKey {
        case fromToken, toToken
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        fromToken = try container.decode(SwapQuote.Token.self, forKey: .fromToken)
        toToken = try container.decode(SwapQuote.Token.self, forKey: .toToken)
    }
}

extension SwapQuote.Token {
    public static func == (lhs: SwapQuote.Token, rhs: TokenToSwap) -> Bool {
        return lhs.address.sameContract(as: rhs.address) && lhs.chainId == rhs.server.chainID
    }
}

extension SwapQuote.Token: Decodable {
    private enum Keys: String, CodingKey {
        case address, chainId, coinKey, decimals, logoURI, name, priceUSD, symbol
    }

    private struct ParsingError: Error {
        let fieldName: Keys
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)

        let addressString = try container.decode(String.self, forKey: .address)
        address = try AlphaWallet.Address(string: addressString) ?? { throw ParsingError(fieldName: .address) }()
        chainId = try container.decode(Int.self, forKey: .chainId)
        coinKey = try container.decode(String.self, forKey: .coinKey)
        decimals = try container.decode(Int.self, forKey: .decimals)
        logoURI = try container.decodeIfPresent(String.self, forKey: .logoURI)
        name = try container.decode(String.self, forKey: .name)
        priceUSD = try container.decode(String.self, forKey: .priceUSD)
        symbol = try container.decode(String.self, forKey: .symbol)
    }
}
