//
//  AmountTextField_v2ViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.03.2022.
//

import Foundation
import UIKit
import Combine
import AlphaWalletFoundation

struct AmountTextField_v2ViewModelInput {
    let togglePair: AnyPublisher<Void, Never>
}

struct AmountTextField_v2ViewModelOutput {
    let etherAmountToSend: AnyPublisher<String?, Never>
    let alternativeAmount: AnyPublisher<String?, Never>
    let currentPair: AnyPublisher<AmountTextField_v2.Pair?, Never>
    let accessoryButtonTitle: AnyPublisher<AmountTextField_v2.AccessoryButtonTitle, Never>
    let errorState: AnyPublisher<AmountTextField_v2.ErrorState, Never>
    let text: AnyPublisher<String?, Never>
}

final class AmountTextField_v2ViewModel {
    //NOTE: Raw values for eth and fiat values. To prevent recalculation we store entered eth and calculated dollarCostRawValue values and vice versa.
    private var cryptoRawValue: NSDecimalNumber?
    private var fiatRawValue: NSDecimalNumber?
    private (set) var cryptoToFiatRate = CurrentValueSubject<NSDecimalNumber?, Never>(nil)
    private (set) var cryptoCurrency = CurrentValueSubject<AmountTextField_v2.FiatOrCrypto?, Never>(nil)
    private (set) var currentPair = CurrentValueSubject<AmountTextField_v2.Pair?, Never>(nil)
    private var cryptoValueChangedSubject = PassthroughSubject<CryptoValueChangeEvent, Never>()
    private var cancelable = Set<AnyCancellable>()
    private var isAllFunds: Bool = false

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
        return cryptoValueOrPairChanged.map { _, _ in return self.alternativeAmountRawValue }
            .removeDuplicates()
            .map { value -> String? in
                let amount = self.formatValueToDisplayValue(value, usesGroupingSeparator: true)

                if amount.isEmpty {
                    let atLeastOneWhiteSpaceToKeepTextFieldHeight = " "
                    return atLeastOneWhiteSpaceToKeepTextFieldHeight
                } else {
                    switch self.currentPair.value?.left {
                    case .cryptoCurrency:
                        return "~ \(amount) \(Currency.USD.rawValue)"
                    case .fiatCurrency:
                        switch self.currentPair.value?.right {
                        case .cryptoCurrency(let tokenObject):
                            return "~ \(amount) " + tokenObject.symbol
                        case .fiatCurrency, .none:
                            return nil
                        }
                    case .none:
                        return nil
                    }
                }
            }.filter { $0 != nil }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    private var cryptoValueOrPairChanged: AnyPublisher<((crypto: String, shortCrypto: String?, useFormatting: Bool), AmountTextField_v2.Pair?), Never> {
        return Publishers.CombineLatest(cryptoValueChanged, currentPair)
            .share()
            .eraseToAnyPublisher()
    }

    private var etherAmountToSend: AnyPublisher<String?, Never> {
        return cryptoValueOrPairChanged
            .map { values, currentPair -> String? in
                switch currentPair?.left {
                case .cryptoCurrency:
                    if values.useFormatting {
                        return self.formatValueToDisplayValue(self.cryptoRawValue)
                    } else if let shortCrypto = values.shortCrypto, shortCrypto.optionalDecimalValue != 0 {
                        return shortCrypto
                    } else {
                        return values.crypto
                    }
                case .fiatCurrency:
                    return self.formatValueToDisplayValue(self.fiatRawValue)
                case .none:
                    return nil
                }
            }.removeDuplicates()
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    @Published var errorState: AmountTextField_v2.ErrorState = .none
    @Published var accessoryButtonTitle: AmountTextField_v2.AccessoryButtonTitle = .done
    let fallbackValue: String = "0"

    var cryptoValueChanged: AnyPublisher<(crypto: String, shortCrypto: String?, useFormatting: Bool), Never> {
        cryptoValueChangedSubject.map { event -> (crypto: String, shortCrypto: String?, useFormatting: Bool) in
            switch event {
            case .manually(let crypto, let shortCrypto, let useFormatting):
                let valueToSet = crypto.optionalDecimalValue
                self.cryptoRawValue = valueToSet
                self.recalculate(amountValue: valueToSet, for: self.cryptoCurrency.value)

                return (crypto: crypto, shortCrypto: shortCrypto, useFormatting: useFormatting)
            case .whenTextChanged(let crypto, let shortCrypto, let useFormatting):
                return (crypto: crypto, shortCrypto: shortCrypto, useFormatting: useFormatting)
            }
        }.eraseToAnyPublisher()
    }

    let debugName: String

    init(token: Token?, debugName: String) {
        self.debugName = debugName
        cryptoCurrency.value = token.flatMap { .cryptoCurrency($0) }
        currentPair.value = token.flatMap { AmountTextField_v2.Pair(left: .cryptoCurrency($0), right: .fiatCurrency(.USD)) }
    }

    func transform(input: AmountTextField_v2ViewModelInput) -> AmountTextField_v2ViewModelOutput {
        cryptoToFiatRate.removeDuplicates()
            .combineLatest(currentPair) { _, pair -> AmountTextField_v2.Pair? in return pair }
            .compactMap { $0 }
            .sink { [weak self] pair in
                guard let strongSelf = self else { return }

                switch pair.left {
                case .cryptoCurrency:
                    strongSelf.recalculate(amountValue: strongSelf.cryptoRawValue)
                case .fiatCurrency:
                    strongSelf.recalculate(amountValue: strongSelf.fiatRawValue)
                }
            }.store(in: &cancelable)

        let currentPair = currentPair
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        let accessoryButtonTitle = $accessoryButtonTitle
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        let errorState = $errorState
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        let text = toggleFiatAndCryptoPair(trigger: input.togglePair)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        return .init(etherAmountToSend: etherAmountToSend, alternativeAmount: alternativeAmount, currentPair: currentPair, accessoryButtonTitle: accessoryButtonTitle, errorState: errorState, text: text)
    }

    func set(token: Token?) {
        cryptoCurrency.value = token.flatMap { .cryptoCurrency($0) }
        currentPair.value = token.flatMap { AmountTextField_v2.Pair(left: .cryptoCurrency($0), right: .fiatCurrency(.USD)) }
    }

    func crypto(for enteredString: String?) -> String {
        var ethCostFormatedForCurrentLocale: String {
            switch currentPair.value?.left {
            case .cryptoCurrency:
                return enteredString?.droppedTrailingZeros ?? fallbackValue
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
    func formatValueToDisplayValue(_ value: NSDecimalNumber?, usesGroupingSeparator: Bool = false) -> String {
        guard let amount = value, let pair = currentPair.value else {
            return String()
        }

        switch pair.left {
        case .cryptoCurrency:
            return StringFormatter().currency(with: amount, and: Currency.USD.rawValue, usesGroupingSeparator: usesGroupingSeparator)
        case .fiatCurrency:
            return StringFormatter().alternateAmount(value: amount, usesGroupingSeparator: usesGroupingSeparator)
        }
    }

    func set(crypto: String, shortCrypto: String? = .none, useFormatting: Bool) {
        cryptoValueChangedSubject.send(.manually(crypto: crypto, shortCrypto: shortCrypto, useFormatting: useFormatting))
    }

    func set(crypto: String) {
        //NOTE: Set raw value (ethCost, dollarCost) and recalculate alternative value
        guard let pair = currentPair.value else { return }

        switch pair.left {
        case .cryptoCurrency:
            cryptoRawValue = crypto.optionalDecimalValue

            recalculate(amountValue: cryptoRawValue)
        case .fiatCurrency:
            fiatRawValue = crypto.optionalDecimalValue

            recalculate(amountValue: fiatRawValue)
        }

        let crypto = self.crypto(for: crypto)
        cryptoValueChangedSubject.send(.whenTextChanged(crypto: crypto, shortCrypto: nil, useFormatting: false))
    }

    private func toggleFiatAndCryptoPair(trigger: AnyPublisher<Void, Never>) -> AnyPublisher<String?, Never> {
        return trigger.filter { _ in self.cryptoToFiatRate.value != nil }
            .map { _ -> String? in
                let oldAlternateAmount = self.formatValueToDisplayValue(self.alternativeAmountRawValue)
                self.toggleFiatAndCryptoPair()

                return oldAlternateAmount
            }.eraseToAnyPublisher()
    }

    ///Recalculates raw value (eth, or usd) depends on selected currency `currencyToOverride ?? currentPair.left` based on cryptoToDollarRate
    private func recalculate(amountValue: NSDecimalNumber?, for currencyToOverride: AmountTextField_v2.FiatOrCrypto? = nil) {
        guard let cryptoToDollarRate = cryptoToFiatRate.value else {
            return
        }

        switch currencyToOverride ?? currentPair.value?.left {
        case .cryptoCurrency:
            if let amount = amountValue {
                fiatRawValue = amount.multiplying(by: cryptoToDollarRate)
            } else {
                fiatRawValue = nil
            }
        case .fiatCurrency:
            if let amount = amountValue {
                cryptoRawValue = amount.dividing(by: cryptoToDollarRate)
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
    }
}
