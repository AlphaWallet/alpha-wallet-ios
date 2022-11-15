//
//  SwapQuoteDetailsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import UIKit
import Combine
import BigInt
import AlphaWalletFoundation

struct SwapQuoteDetailsViewModelInput {

}

struct SwapQuoteDetailsViewModelOutput {
    let isHidden: AnyPublisher<Bool, Never>
}

final class SwapQuoteDetailsViewModel {
    private let etherFormatter: EtherNumberFormatter = .plain
    private (set) lazy var exchangeViewModel = SwapQuoteFieldViewModel(title: "Exchange", value: exchangeString)
    private (set) lazy var totalFeeViewModel = SwapQuoteFieldViewModel(title: "Gas Cost", value: gasCostString)
    private (set) lazy var currentPriceViewModel = SwapQuoteFieldViewModel(title: "Current Price", value: currentPriceString)
    private (set) lazy var minimumReceivedViewModel = SwapQuoteFieldViewModel(title: "Minimum Received", value: minimumReceivedString)
    private (set) lazy var swapStepsViewModel = SwapStepsViewModel(swapSteps: swapSteps)
    private let decimalParser = DecimalParser()

    var backgoundColor: UIColor = R.color.alabaster()!

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
                    return SwapStep(tool: pair.swapQuote.type, subSteps: subSteps)
                }
            }.eraseToAnyPublisher()
    }()

    private lazy var minimumReceivedString: AnyPublisher<String, Never> = {
        configurator.tokensWithTheirSwapQuote
            .map { data -> String in
                guard let data = data else { return "-" }
                let amount = EtherNumberFormatter.short.string(from: data.swapQuote.estimate.toAmountMin, decimals: data.tokens.to.decimals)
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
            .map { data -> String in
                guard let pair = data.1, let gasCosts = pair.swapQuote.estimate.gasCosts.first else { return "-" }

                let amount = EtherNumberFormatter.short.string(from: gasCosts.amount, decimals: gasCosts.token.decimals)

                return "\(amount) \(gasCosts.token.symbol) ~ \(gasCosts.amountUsd.droppedTrailingZeros) USD"
            }.removeDuplicates()
            .eraseToAnyPublisher()
    }()

    private lazy var currentPriceString: AnyPublisher<String, Never> = {
        Publishers.CombineLatest(configurator.validatedAmount, configurator.tokensWithTheirSwapQuote)
            .map { [etherFormatter, decimalParser] data -> String in
                guard let pair = data.1 else { return "" }

                let toAmount = etherFormatter.string(from: pair.swapQuote.estimate.toAmount, decimals: pair.tokens.to.decimals)
                let fromAmount = etherFormatter.string(from: data.0, decimals: pair.tokens.from.decimals)

                guard
                    let toAmount = decimalParser.parseAnyDecimal(from: toAmount)?.doubleValue,
                    let fromAmount = decimalParser.parseAnyDecimal(from: fromAmount)?.doubleValue
                else { return "-" }

                let rate: Double? = {
                    guard fromAmount > 0 else { return nil }
                    return (toAmount / fromAmount).nilIfNan
                }()
                guard let cryptoToCryptoRate = rate.flatMap({ Formatter.shortCrypto(symbol: pair.tokens.to.symbol).string(from: $0) }) else { return "-" }

                return "1 \(pair.tokens.from.symbol) = \(cryptoToCryptoRate)"
            }.removeDuplicates()
            .eraseToAnyPublisher()
    }()

    private let configurator: SwapOptionsConfigurator

    init(configurator: SwapOptionsConfigurator) {
        self.configurator = configurator
    }
}

extension TokenLevelTokenScriptDisplayStatus.SignatureValidationError {
    var localizedDescription: String {
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
