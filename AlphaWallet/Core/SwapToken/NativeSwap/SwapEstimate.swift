// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import BigInt

struct SwapEstimate {
    let spender: AlphaWallet.Address
    let toAmount: BigUInt
    let toAmountMin: BigUInt
    let feeCosts: [FeeCost]
    let gasCosts: [GasCost]
    
    struct FeeCost {
        let name: String
        let percentage: String
        let amount: BigUInt
        let token: SwapQuote.Token
    }

    struct GasCost {
        let type: String
        let amount: BigUInt
        let amountUsd: String
        let estimate: BigUInt
        let limit: BigUInt
        let token: SwapQuote.Token
    }

    struct SwapStep {
        let unsignedSwapTransaction: UnsignedSwapTransaction
        let estimate: SwapEstimate
        let action: SwapQuote.Action
        let tool: String
        let type: String
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

    init(from decoder: Decoder) throws {
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

    init(from decoder: Decoder) throws {
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

    init(from decoder: Decoder) throws {
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

    init(from decoder: Decoder) throws {
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
