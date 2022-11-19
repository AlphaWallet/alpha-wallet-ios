//
//  AmountTextFieldViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.03.2022.
//

import Foundation
import UIKit
import Combine
import AlphaWalletFoundation

struct AmountTextFieldViewModelInput {
    let togglePair: AnyPublisher<Void, Never>
}

struct AmountTextFieldViewModelOutput {
    let text: AnyPublisher<String?, Never>
    let alternativeAmount: AnyPublisher<String?, Never>
    let currentPair: AnyPublisher<AmountTextField.Pair?, Never>
    let errorState: AnyPublisher<AmountTextField.ErrorState, Never>
}

final class AmountTextFieldViewModel {
    static let allowedCharacters: String = {
        let decimalSeparator = Config.locale.decimalSeparator ?? ""
        return "0123456789" + decimalSeparator + EtherNumberFormatter.decimalPoint
    }()

    //NOTE: Raw values for eth and fiat values. To prevent recalculation we store entered eth and calculated dollarCostRawValue values and vice versa.
    private (set) var cryptoRawValue: NSDecimalNumber?
    private (set) var fiatRawValue: NSDecimalNumber?
    private (set) var cryptoToFiatRate = CurrentValueSubject<NSDecimalNumber?, Never>(nil)
    private (set) var cryptoCurrency = CurrentValueSubject<AmountTextField.FiatOrCrypto?, Never>(nil)
    private (set) var currentPair = CurrentValueSubject<AmountTextField.Pair?, Never>(nil)
    private var cryptoValueChangedSubject = PassthroughSubject<CryptoValueChangeEvent, Never>()
    private var cancelable = Set<AnyCancellable>()
    var isAllFunds: Bool = false

    ///Returns raw (calculated) value based on selected currency
    private var alternativeAmountRawValue: NSDecimalNumber? {
        guard let pair = currentPair.value else { return nil }
        switch pair.left {
        case .cryptoCurrency:
            return fiatRawValue
        case .fiatCurrency:
            return cryptoRawValue
        }
    }

    private var alternativeAmount: AnyPublisher<String?, Never> {
        return cryptoValueOrPairChanged
            .map { _, _ -> NSDecimalNumber? in return self.alternativeAmountRawValue }
            .removeDuplicates()
            .map { value -> String? in
                let amount = self.formatValueToDisplay(value: value, usesGroupingSeparator: true)

                if amount.isEmpty {
                    let atLeastOneWhiteSpaceToKeepTextFieldHeight = " "
                    return atLeastOneWhiteSpaceToKeepTextFieldHeight
                } else {
                    guard let pair = self.currentPair.value else { return nil }
                    switch pair.left {
                    case .cryptoCurrency:
                        return "~ \(amount) \(pair.fiat.rawValue)"
                    case .fiatCurrency:
                        switch pair.right {
                        case .cryptoCurrency(let token):
                            return "~ \(amount) " + token.symbol
                        case .fiatCurrency:
                            return nil
                        }
                    }
                }
            }.filter { $0 != nil }
            .eraseToAnyPublisher()
    }

    private var cryptoValueOrPairChanged: AnyPublisher<(CryptoValueChangeEvent, AmountTextField.Pair?), Never> {
        return Publishers.CombineLatest(cryptoValueChanged, currentPair)
            .share()
            .eraseToAnyPublisher()
    }

    @Published var errorState: AmountTextField.ErrorState = .none
    private let fallbackValue: String = "0"
    private var lastValueChangeEvent: CryptoValueChangeEvent?

    var cryptoValueChanged: AnyPublisher<CryptoValueChangeEvent, Never> {
        cryptoValueChangedSubject.map { event -> CryptoValueChangeEvent in
            switch event {
            case .manually(let crypto, let shortCrypto, let useFormatting):
                let valueToSet = crypto.optionalDecimalValue
                self.cryptoRawValue = valueToSet
                self.recalculate(amountValue: valueToSet, for: self.cryptoCurrency.value)

                return .manually(crypto: crypto, shortCrypto: shortCrypto, useFormatting: useFormatting)
            case .whenTextChanged(let crypto, let shortCrypto, let useFormatting):
                return .whenTextChanged(crypto: crypto, shortCrypto: shortCrypto, useFormatting: useFormatting)
            }
        }.handleEvents(receiveOutput: { [weak self] in self?.lastValueChangeEvent = $0 })
        .eraseToAnyPublisher()
    }

    let debugName: String

    init(token: Token?, debugName: String) {
        self.debugName = debugName
        cryptoCurrency.value = token.flatMap { .cryptoCurrency($0) }
        currentPair.value = token.flatMap { AmountTextField.Pair(left: .cryptoCurrency($0), right: .fiatCurrency(.USD)) }
    }

    func transform(input: AmountTextFieldViewModelInput) -> AmountTextFieldViewModelOutput {
        cryptoToFiatRate
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let strongSelf = self else { return }

                switch strongSelf.currentPair.value?.left {
                case .cryptoCurrency: strongSelf.recalculate(amountValue: strongSelf.cryptoRawValue)
                case .fiatCurrency: strongSelf.recalculate(amountValue: strongSelf.fiatRawValue)
                case .none: break
                }
            }.store(in: &cancelable)

        let currentPair = currentPair
            .eraseToAnyPublisher()

        let errorState = $errorState
            .eraseToAnyPublisher()

        let cryptoAmountToSend = cryptoValueOrPairChanged.filter { $0.0.shouldChangeText }
            .map { event, currentPair -> String? in
                switch currentPair?.left {
                case .cryptoCurrency:
                    if event.useFormatting {
                        return self.formatValueToDisplay(value: self.cryptoRawValue)
                    } else if let shortCrypto = event.shortCrypto, shortCrypto.optionalDecimalValue != 0 {
                        return shortCrypto
                    } else {
                        return event.crypto
                    }
                case .fiatCurrency:
                    return self.formatValueToDisplay(value: self.fiatRawValue)
                case .none:
                    return nil
                }
            }.eraseToAnyPublisher()

        let text = Publishers.Merge(cryptoAmountToSend, toggleFiatAndCryptoPair(trigger: input.togglePair))
            .eraseToAnyPublisher()

        return .init(text: text, alternativeAmount: alternativeAmount, currentPair: currentPair, errorState: errorState)
    }

    func set(token: Token?) {
        cryptoCurrency.value = token.flatMap { .cryptoCurrency($0) }
        currentPair.value = token.flatMap { AmountTextField.Pair(left: .cryptoCurrency($0), right: .fiatCurrency(.USD)) }
    }

    func crypto(for string: String?) -> String {
        var ethCostFormatedForCurrentLocale: String {
            switch currentPair.value?.left {
            case .cryptoCurrency:
                return string?.droppedTrailingZeros ?? fallbackValue
            case .fiatCurrency:
                guard let value = cryptoRawValue else { return fallbackValue }
                return StringFormatter().alternateAmount(value: value, usesGroupingSeparator: false)
            case .none:
                return String()
            }
        }

        if isAllFunds {
            return cryptoRawValue.localizedString
        } else {
            if let value = ethCostFormatedForCurrentLocale.optionalDecimalValue {
                return value.localizedString
            } else {
                return fallbackValue
            }
        }
    }

    func toggleFiatAndCryptoPair() {
        currentPair.value?.swap()
    }

    ///Formats string value for display in text field.
    private func formatValueToDisplay(value: NSDecimalNumber?, usesGroupingSeparator: Bool = false) -> String {
        guard let amount = value, let pair = currentPair.value else {
            return String()
        }

        switch pair.left {
        case .cryptoCurrency:
            return StringFormatter().currency(with: amount, and: pair.fiat.rawValue, usesGroupingSeparator: usesGroupingSeparator)
        case .fiatCurrency:
            return StringFormatter().alternateAmount(value: amount, usesGroupingSeparator: usesGroupingSeparator)
        }
    }

    func set(crypto: String, shortCrypto: String? = .none, useFormatting: Bool) {
        cryptoValueChangedSubject.send(.manually(crypto: crypto, shortCrypto: shortCrypto, useFormatting: useFormatting))
    }

    func set(string: String) {
        //NOTE: Set raw value (ethCost, dollarCost) and recalculate alternative value
        guard let pair = currentPair.value else { return }

        switch pair.left {
        case .cryptoCurrency:
            cryptoRawValue = string.optionalDecimalValue

            recalculate(amountValue: cryptoRawValue)
        case .fiatCurrency:
            fiatRawValue = string.optionalDecimalValue

            recalculate(amountValue: fiatRawValue)
        }

        let entered = self.crypto(for: string)
        cryptoValueChangedSubject.send(.whenTextChanged(crypto: entered, shortCrypto: nil, useFormatting: false))
    }

    private func toggleFiatAndCryptoPair(trigger: AnyPublisher<Void, Never>) -> AnyPublisher<String?, Never> {
        return trigger.filter { _ in self.cryptoToFiatRate.value != nil }
            .map { _ -> String? in
                let oldAlternateAmount = self.formatValueToDisplay(value: self.alternativeAmountRawValue)
                self.toggleFiatAndCryptoPair()

                return oldAlternateAmount
            }.eraseToAnyPublisher()
    }

    ///Recalculates raw value (eth, or usd) depends on selected currency `currencyToOverride ?? currentPair.left` based on cryptoToDollarRate
    private func recalculate(amountValue: NSDecimalNumber?, for currencyToOverride: AmountTextField.FiatOrCrypto? = nil) {
        guard let cryptoToFiatRate = cryptoToFiatRate.value else {
            return
        }

        switch currencyToOverride ?? currentPair.value?.left {
        case .cryptoCurrency:
            if let amount = amountValue {
                fiatRawValue = amount.multiplying(by: cryptoToFiatRate)
            } else {
                fiatRawValue = nil
            }
        case .fiatCurrency:
            if let amount = amountValue {
                cryptoRawValue = amount.dividing(by: cryptoToFiatRate)
            } else {
                cryptoRawValue = nil
            }
        case .none:
            break
        }
    }

    enum CryptoValueChangeEvent {
        case manually(crypto: String, shortCrypto: String? = .none, useFormatting: Bool)
        case whenTextChanged(crypto: String, shortCrypto: String? = .none, useFormatting: Bool)

        var shouldChangeText: Bool {
            switch self {
            case .manually:
                return true
            case .whenTextChanged:
                return false
            }
        }
        var crypto: String {
            switch self {
            case .manually(let crypto, _, _):
                return crypto
            case .whenTextChanged(let crypto, _, _):
                return crypto
            }
        }

        var shortCrypto: String? {
            switch self {
            case .manually(_, let shortCrypto, _):
                return shortCrypto
            case .whenTextChanged(_, let shortCrypto, _):
                return shortCrypto
            }
        }

        var useFormatting: Bool {
            switch self {
            case .manually(_, _, let useFormatting):
                return useFormatting
            case .whenTextChanged(_, _, let useFormatting):
                return useFormatting
            }
        }
    }
}
