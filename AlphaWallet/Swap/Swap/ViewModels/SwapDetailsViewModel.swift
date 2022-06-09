//
//  SwapDetailsViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import UIKit
import Combine
import BigInt

extension SwapOptionsConfigurator {
    var tokensWithTheirSwapQuote: AnyPublisher<(swapQuote: SwapQuote, tokens: FromAndToTokens)?, Never> {
        return swapQuote.combineLatest(fromAndToTokensPublisher)
            .map { (swapQuote, tokens) -> (swapQuote: SwapQuote, tokens: FromAndToTokens)? in
                guard let swapQuote = swapQuote, let tokens = tokens else { return nil }
                return (swapQuote, tokens)
            }.eraseToAnyPublisher()
    }
}

final class SwapDetailsViewModel {
    private var swapDetailsExpanded: Bool = false

    lazy var totalFeeViewModel = FieldViewModel(title: "Fees", value: totalFeeString)
    lazy var currentPriceViewModel = FieldViewModel(title: "Current Price", value: currentPriceString)
    lazy var minimumReceivedViewModel = FieldViewModel(title: "Minimum Received", value: minimumReceivedString)
    var swapFeesViewModel = SwapFeesViewModel(providers: [])
    var backgoundColor: UIColor = R.color.alabaster()!

    var isHidden: AnyPublisher<Bool, Never> {
        configurator.tokensWithTheirSwapQuote
            .map { $0 == nil }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private lazy var minimumReceivedString: AnyPublisher<String, Never> = {
        configurator.tokensWithTheirSwapQuote
            .map { data -> String in
                guard let data = data else { return "-" }
                let amount = EtherNumberFormatter.short.string(from: BigInt(data.swapQuote.estimate.toAmountMin))
                return "\(amount) \(data.tokens.to.symbol)"
            }.eraseToAnyPublisher()
    }()

    private lazy var totalFeeString: AnyPublisher<String, Never> = {
        Publishers.CombineLatest(configurator.validatedAmount, configurator.tokensWithTheirSwapQuote)
            .map { data -> String in
                guard let pair = data.1 else { return "-" }

                let receivedAmount = EtherNumberFormatter.full.string(from: BigInt(pair.swapQuote.estimate.toAmount))
                let fromAmount = EtherNumberFormatter.full.string(from: BigInt(data.0))

                let fee = EtherNumberFormatter.full.string(from: BigInt(pair.swapQuote.unsignedSwapTransaction.gasLimit * pair.swapQuote.unsignedSwapTransaction.gasPrice))

                guard
                    let receivedAmount = receivedAmount.optionalDecimalValue?.doubleValue,
                    let fromAmount = fromAmount.optionalDecimalValue?.doubleValue,
                    let feeAmount = fee.optionalDecimalValue?.doubleValue
                else { return "-" }

                let rate: Double? = {
                    let value = fromAmount - receivedAmount
                    return value.isNaN ? nil : abs(value)
                }()

                guard let totalFee = rate.flatMap({ Formatter.shortCrypto(symbol: pair.tokens.from.symbol).string(from: $0 + feeAmount) }) else { return "-" }

                return totalFee
            }.eraseToAnyPublisher()
    }()

    private lazy var currentPriceString: AnyPublisher<String, Never> = {
        Publishers.CombineLatest(configurator.validatedAmount, configurator.tokensWithTheirSwapQuote)
            .map { data -> String in
                guard let pair = data.1 else { return "-" }

                let receivedAmount = EtherNumberFormatter.full.string(from: BigInt(pair.swapQuote.estimate.toAmount))
                let fromAmount = EtherNumberFormatter.full.string(from: BigInt(data.0))

                guard
                    let receivedAmount = receivedAmount.optionalDecimalValue?.doubleValue,
                    let fromAmount = fromAmount.optionalDecimalValue?.doubleValue
                else { return "-" }

                let rate: Double? = {
                    guard fromAmount > 0 else { return nil }
                    return (receivedAmount / fromAmount).nilIfNan
                }()
                guard let cryptoToCryptoRate = rate.flatMap({ Formatter.shortCrypto(symbol: pair.tokens.to.symbol).string(from: $0) }) else { return "-" }

                return "1 \(pair.tokens.from.symbol) = \(cryptoToCryptoRate)"
            }.eraseToAnyPublisher()
    }()

    private let configurator: SwapOptionsConfigurator

    init(configurator: SwapOptionsConfigurator) {
        self.configurator = configurator
    }

    func toggleExpanded() {
        swapDetailsExpanded.toggle()
    } 
}
