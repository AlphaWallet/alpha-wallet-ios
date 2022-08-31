// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import BigInt

public struct SwapEstimate {
    public let spender: AlphaWallet.Address
    public let toAmount: BigUInt
    public let toAmountMin: BigUInt
    public let feeCosts: [FeeCost]
    public let gasCosts: [GasCost]
    
    public struct FeeCost {
        public let name: String
        public let percentage: String
        public let amount: BigUInt
        public let token: SwapQuote.Token
    }

    public struct GasCost {
        public let type: String
        public let amount: BigUInt
        public let amountUsd: String
        public let estimate: BigUInt
        public let limit: BigUInt
        public let token: SwapQuote.Token
    }

    public struct SwapStep {
        public let unsignedSwapTransaction: UnsignedSwapTransaction
        public let estimate: SwapEstimate
        public let action: SwapQuote.Action
        public let tool: String
        public let type: String
    }
}

extension SwapEstimate: Decodable {
    private enum Keys: String, CodingKey {
        case approvalAddress
        case toAmount
        case toAmountMin
        case feeCosts
        case gasCosts
        case steps = "includedSteps"
    }

    private struct ParsingError: Error {
        let fieldName: Keys
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)

        let spenderString = try container.decode(String.self, forKey: .approvalAddress)
        spender = try AlphaWallet.Address(string: spenderString) ?? { throw ParsingError(fieldName: .approvalAddress) }()
        let toAmountString = try container.decode(String.self, forKey: .toAmount)
        toAmount = try BigUInt(toAmountString) ?? { throw ParsingError(fieldName: .toAmount) }()
        let toAmountMinString = try container.decode(String.self, forKey: .toAmountMin)
        toAmountMin = try BigUInt(toAmountMinString) ?? { throw ParsingError(fieldName: .toAmountMin) }()
        feeCosts = try container.decode([SwapEstimate.FeeCost].self, forKey: .feeCosts)
        gasCosts = try container.decode([SwapEstimate.GasCost].self, forKey: .gasCosts)
    }
}

extension SwapEstimate.SwapStep: Decodable {
    private enum Keys: String, CodingKey {
        case transactionRequest
        case estimate
        case action
        case tool
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        unsignedSwapTransaction = try container.decode(UnsignedSwapTransaction.self, forKey: .transactionRequest)
        estimate = try container.decode(SwapEstimate.self, forKey: .estimate)
        action = try container.decode(SwapQuote.Action.self, forKey: .action)
        tool = try container.decode(String.self, forKey: .tool)
        type = try container.decode(String.self, forKey: .type)
    }
}

extension SwapEstimate.FeeCost: Decodable {
    private enum Keys: String, CodingKey {
        case name
        case percentage
        case amount
        case token
    }

    private struct ParsingError: Error {
        let fieldName: Keys
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        name = try container.decode(String.self, forKey: .name)
        percentage = try container.decode(String.self, forKey: .percentage)
        let amountString = try container.decode(String.self, forKey: .amount)
        amount = try BigUInt(amountString) ?? { throw ParsingError(fieldName: .amount) }()
        token = try container.decode(SwapQuote.Token.self, forKey: .token)
    }
}

extension SwapEstimate.GasCost: Decodable {
    private enum Keys: String, CodingKey {
        case amount
        case amountUsd = "amountUSD"
        case estimate
        case limit
        case token
        case type
    }

    private struct ParsingError: Error {
        let fieldName: Keys
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        type = try container.decode(String.self, forKey: .type)
        let amountString = try container.decode(String.self, forKey: .amount)
        amount = try BigUInt(amountString) ?? { throw ParsingError(fieldName: .amount) }()
        amountUsd = try container.decode(String.self, forKey: .amountUsd)
        let estimateString = try container.decode(String.self, forKey: .estimate)
        estimate = try BigUInt(estimateString) ?? { throw ParsingError(fieldName: .amount) }()
        let limitString = try container.decode(String.self, forKey: .estimate)
        limit = try BigUInt(limitString) ?? { throw ParsingError(fieldName: .amount) }()
        token = try container.decode(SwapQuote.Token.self, forKey: .token)
    }
}
