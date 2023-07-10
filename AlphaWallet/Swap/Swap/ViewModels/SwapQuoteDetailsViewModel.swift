//
//  SwapQuoteDetailsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import Combine
import UIKit
import AlphaWalletFoundation
import enum AlphaWalletTokenScript.TokenLevelTokenScriptDisplayStatus
import BigInt

struct SwapQuoteDetailsViewModelInput {

}

struct SwapQuoteDetailsViewModelOutput {
    let isHidden: AnyPublisher<Bool, Never>
}

final class SwapQuoteDetailsViewModel {
    private let formatter = NumberFormatter.shortCrypto
    private (set) lazy var exchangeViewModel = SwapQuoteFieldViewModel(title: "Exchange", value: exchangeString)
    private (set) lazy var totalFeeViewModel = SwapQuoteFieldViewModel(title: "Gas Cost", value: gasCostString)
    private (set) lazy var currentPriceViewModel = SwapQuoteFieldViewModel(title: "Current Price", value: currentPriceString)
    private (set) lazy var minimumReceivedViewModel = SwapQuoteFieldViewModel(title: "Minimum Received", value: minimumReceivedString)
    private (set) lazy var swapStepsViewModel = SwapStepsViewModel(swapSteps: swapSteps)

    func transform(input: SwapQuoteDetailsViewModelInput) -> SwapQuoteDetailsViewModelOutput {
        let isHidden = configurator.tokensWithTheirSwapQuote
            .map { $0 == nil }
            .removeDuplicates()

        return .init(isHidden: isHidden.eraseToAnyPublisher())
    }

    private lazy var swapSteps: AnyPublisher<[SwapStep], Never> = {
        Publishers.CombineLatest(configurator.validatedAmount, configurator.tokensWithTheirSwapQuote)
            .map { data -> [SwapStep] in
                guard let pair = data.1 else { return [] }
                return pair.swapQuote.steps.map { step in
                    let subSteps = step.estimate.gasCosts.map {
                        SwapSubStep(gasCost: $0, type: step.type, amount: pair.swapQuote.estimate.toAmount, token: pair.swapQuote.action.toToken, tool: step.tool)
                    }

                    if subSteps.isEmpty {
                        let gasCost = SwapEstimate.GasCost(
                            type: step.type,
                            amount: pair.swapQuote.unsignedSwapTransaction.value,
                            amountUsd: pair.swapQuote.action.fromToken.priceUSD,
                            estimate: pair.swapQuote.unsignedSwapTransaction.gasPrice,
                            limit: pair.swapQuote.unsignedSwapTransaction.gasLimit,
                            token: pair.swapQuote.action.fromToken)

                        let step = SwapSubStep(
                            gasCost: gasCost,
                            type: step.type,
                            amount: pair.swapQuote.estimate.toAmount,
                            token: pair.swapQuote.action.toToken,
                            tool: step.tool)

                        return SwapStep(tool: pair.swapQuote.type, subSteps: [step])
                    } else {
                        return SwapStep(tool: pair.swapQuote.type, subSteps: subSteps)
                    }
                }
            }.eraseToAnyPublisher()
    }()

    private lazy var minimumReceivedString: AnyPublisher<String, Never> = {
        configurator.tokensWithTheirSwapQuote
            .map { [formatter] data -> String in
                guard let data = data else { return "-" }
                let doubleAmount = (Decimal(bigUInt: data.swapQuote.estimate.toAmountMin, decimals: data.tokens.to.decimals) ?? .zero).doubleValue
                let amount = formatter.string(double: doubleAmount, minimumFractionDigits: 4, maximumFractionDigits: 8)

                return "\(amount) \(data.tokens.to.symbol)"
            }.removeDuplicates()
            .eraseToAnyPublisher()
    }()

    private lazy var exchangeString: AnyPublisher<String, Never> = {
        Publishers.CombineLatest(configurator.validatedAmount, configurator.tokensWithTheirSwapQuote)
            .map { $0.1?.swapQuote.tool ?? "-" }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()

    private lazy var gasCostString: AnyPublisher<String, Never> = {
        Publishers.CombineLatest(configurator.validatedAmount, configurator.tokensWithTheirSwapQuote)
            .map { [formatter] data -> String in
                guard let pair = data.1, let gasCosts = pair.swapQuote.estimate.gasCosts.first else { return "-" }

                let doubleAmount = (Decimal(bigUInt: gasCosts.amount, decimals: gasCosts.token.decimals) ?? .zero).doubleValue
                let amount = formatter.string(double: doubleAmount, minimumFractionDigits: 4, maximumFractionDigits: 8)

                return "\(amount) \(gasCosts.token.symbol) ~ \(gasCosts.amountUsd.droppedTrailingZeros) \(Currency.USD.code)"
            }.removeDuplicates()
            .eraseToAnyPublisher()
    }()

    private lazy var currentPriceString: AnyPublisher<String, Never> = {
        Publishers.CombineLatest(configurator.validatedAmount, configurator.tokensWithTheirSwapQuote)
            .map { [formatter] data -> String in
                guard let pair = data.1 else { return "" }

                let toAmount = (Decimal(bigUInt: pair.swapQuote.estimate.toAmount, decimals: pair.tokens.to.decimals) ?? .zero).doubleValue
                let fromAmount = (Decimal(bigUInt: data.0, decimals: pair.tokens.from.decimals) ?? .zero).doubleValue

                let rate: Double? = {
                    guard fromAmount > 0 else { return nil }
                    return (toAmount / fromAmount).nilIfNan
                }()
                guard let rate = rate else { return "-" }

                let amount = formatter.string(double: rate, minimumFractionDigits: 4, maximumFractionDigits: 8)

                return "1 \(pair.tokens.from.symbol) = \(amount) \(pair.tokens.to.symbol)"
            }.removeDuplicates()
            .eraseToAnyPublisher()
    }()

    private let configurator: SwapOptionsConfigurator

    init(configurator: SwapOptionsConfigurator) {
        self.configurator = configurator
    }
}

extension TokenLevelTokenScriptDisplayStatus.SignatureValidationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .tokenScriptType1SupportedNotCanonicalizedAndUnsigned:
            return R.string.localizable.tokenScriptType1SupportedNotCanonicalizedAndUnsigned()
        case .tokenScriptType1SupportedAndSigned:
            return R.string.localizable.tokenScriptType1SupportedAndSigned()
        case .tokenScriptType2InvalidSignature:
            return R.string.localizable.tokenScriptType2InvalidSignature()
        case .tokenScriptType2ConflictingFiles:
            return R.string.localizable.tokenScriptType2ConflictingFiles()
        case .tokenScriptType2OldSchemaVersion:
            return R.string.localizable.tokenScriptType2OldSchemaVersion()
        case .custom(let value):
            return value
        }
    }
}
