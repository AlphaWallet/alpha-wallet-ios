// Copyright © 2022 Stormbird PTE. LTD.

import Foundation

struct SwapQuote {
    let unsignedSwapTransaction: UnsignedSwapTransaction
    let estimate: SwapEstimate
    let action: SwapQuote.Action
    let steps: [SwapEstimate.SwapStep]
    let tool: String
    let type: String

    struct Action {
        let fromToken: SwapQuote.Token
        let toToken: SwapQuote.Token
    }

    struct Token {
        let address: AlphaWallet.Address
        let chainId: Int
        let coinKey: String
        let decimals: Int
        let logoURI: String?
        let name: String
        let priceUSD: String
        let symbol: String
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

    init(from decoder: Decoder) throws {
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

    init(from decoder: Decoder) throws {
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

    init(from decoder: Decoder) throws {
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
