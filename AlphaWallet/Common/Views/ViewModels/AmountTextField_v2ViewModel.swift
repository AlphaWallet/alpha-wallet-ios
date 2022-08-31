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

class AmountTextField_v2ViewModel: NSObject, ObservableObject {
    //NOTE: Raw values for eth and fiat values. To prevent recalculation we store entered eth and calculated dollarCostRawValue values and vice versa.
    private (set) var cryptoRawValue: NSDecimalNumber?
    private (set) var fiatRawValue: NSDecimalNumber?
    private (set) var cryptoToDollarRate = CurrentValueSubject<NSDecimalNumber?, Never>(nil)
    private (set) var cryptoCurrency = CurrentValueSubject<AmountTextField_v2.FiatOrCrypto?, Never>(nil)
    private (set) var currentPair = CurrentValueSubject<AmountTextField_v2.Pair?, Never>(nil)
    private var cryptoValueChangedSubject = PassthroughSubject<CryptoValueChangeEvent, Never>()

    @Published var errorState: AmountTextField_v2.ErrorState = .none
    @Published var accessoryButtonTitle: AmountTextField_v2.AccessoryButtonTitle = .done

    ///Returns raw (calculated) value based on selected currency
    private var _alternativeAmount: NSDecimalNumber? {
        guard let pair = currentPair.value else { return nil }
        switch pair.left {
        case .cryptoCurrency:
            return fiatRawValue
        case .fiatCurrency:
            return cryptoRawValue
        }
    }

    var alternativeAmount: AnyPublisher<String?, Never> {
        return cryptoValueOrPairChanged.map { _, _ in return self._alternativeAmount }
            .removeDuplicates()
            .map { value -> String? in
                let amount = self.formatValueToDisplayValue(value, usesGroupingSeparator: true)

                if amount.isEmpty {
                    let atLeastOneWhiteSpaceToKeepTextFieldHeight = " "
                    return atLeastOneWhiteSpaceToKeepTextFieldHeight
                } else {
                    switch self.currentPair.value?.left {
                    case .cryptoCurrency:
                        return "~ \(amount) \(Constants.Currency.usd)"
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
            .eraseToAnyPublisher()
    }

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

    private var cryptoValueOrPairChanged: AnyPublisher<((crypto: String, shortCrypto: String?, useFormatting: Bool), AmountTextField_v2.Pair?), Never> {
        return Publishers.CombineLatest(cryptoValueChanged, currentPair)
            .share()
            .eraseToAnyPublisher()
    }

    var etherAmountToSend: AnyPublisher<String?, Never> {
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
            .eraseToAnyPublisher()
    }
    
    let debugName: String
    private var cancelable = Set<AnyCancellable>()

    var isAllFunds: Bool = false

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

    let fallbackValue: String = "0"

    init(token: Token?, debugName: String) {
        self.debugName = debugName
        cryptoCurrency.value = token.flatMap { .cryptoCurrency($0) }
        currentPair.value = token.flatMap { AmountTextField_v2.Pair(left: .cryptoCurrency($0), right: .fiatCurrency(.USD)) }

        super.init()

        cryptoToDollarRate.removeDuplicates()
            .combineLatest(currentPair) { _, pair -> AmountTextField_v2.Pair? in return pair }
            .compactMap { $0 }
            .sink { [weak self] pair in
                guard let `self` = self else { return }

                switch pair.left {
                case .cryptoCurrency:
                    self.recalculate(amountValue: self.cryptoRawValue)
                case .fiatCurrency:
                    self.recalculate(amountValue: self.fiatRawValue)
                }
            }.store(in: &cancelable)
    }

    func toggleFiatAndCryptoPair(trigger: AnyPublisher<Void, Never>) -> AnyPublisher<String?, Never> {
        return trigger.filter { _ in self.cryptoToDollarRate.value != nil }
            .map { _ -> String? in
                let oldAlternateAmount = self.formatValueToDisplayValue(self._alternativeAmount)
                self.toggleFiatAndCryptoPair()

                return oldAlternateAmount
            }.eraseToAnyPublisher()
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
            return StringFormatter().currency(with: amount, and: Constants.Currency.usd, usesGroupingSeparator: usesGroupingSeparator)
        case .fiatCurrency:
            return StringFormatter().alternateAmount(value: amount, usesGroupingSeparator: usesGroupingSeparator)
        }
    }

    ///Recalculates raw value (eth, or usd) depends on selected currency `currencyToOverride ?? currentPair.left` based on cryptoToDollarRate
    private func recalculate(amountValue: NSDecimalNumber?, for currencyToOverride: AmountTextField_v2.FiatOrCrypto? = nil) {
        guard let cryptoToDollarRate = cryptoToDollarRate.value else {
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

    enum CryptoValueChangeEvent {
        case manually(crypto: String, shortCrypto: String? = .none, useFormatting: Bool)
        case whenTextChanged(crypto: String, shortCrypto: String? = .none, useFormatting: Bool)
    }
}
