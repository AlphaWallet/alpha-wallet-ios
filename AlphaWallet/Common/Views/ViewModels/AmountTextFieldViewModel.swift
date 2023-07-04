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

protocol EnterAmountSupportable: HasTokenImage { }

final class AmountTextFieldViewModel {
    private static let atLeastOneWhiteSpaceToKeepTextFieldHeight = " "
    //NOTE: Raw values for eth and fiat values. To prevent recalculation we store entered eth and calculated dollarCostRawValue values and vice versa.
    private (set) var cryptoRawValue: Double? = .none
    private (set) var fiatRawValue: Double? = .none
    private (set) var cryptoToFiatRate = CurrentValueSubject<AmountTextFieldViewModel.CurrencyRate, Never>(.init(value: nil, currency: .default))
    private (set) var currentPair = CurrentValueSubject<AmountTextField.Pair?, Never>(nil)
    private let amountChangedSubject = PassthroughSubject<CryptoValueChangeEvent, Never>()
    private var cancelable = Set<AnyCancellable>()
    private let decimalParser = DecimalParser()

    ///Returns raw (calculated) value based on selected currency
    private var alternativeAmountRawValue: Double? {
        guard let pair = currentPair.value else { return .none }
        switch pair.left {
        case .cryptoCurrency:
            return fiatRawValue
        case .fiatCurrency:
            return cryptoRawValue
        }
    }

    private var alternativeAmount: AnyPublisher<String?, Never> {
        return Publishers.CombineLatest(cryptoValueOrPairChanged, cryptoToFiatRate)
            .map { _, _ -> Double? in return self.alternativeAmountRawValue }
            .removeDuplicates()
            .map { value -> String? in
                let amount = self.buildAlternativeAmountString(value: value, usesGroupingSeparator: true)

                if amount.isEmpty {
                    return AmountTextFieldViewModel.atLeastOneWhiteSpaceToKeepTextFieldHeight
                } else {
                    guard let pair = self.currentPair.value else { return AmountTextFieldViewModel.atLeastOneWhiteSpaceToKeepTextFieldHeight }
                    switch pair.left {
                    case .cryptoCurrency:
                        return "~ \(amount) \(pair.fiat.rawValue)"
                    case .fiatCurrency:
                        switch pair.right {
                        case .cryptoCurrency(let token):
                            return "~ \(amount) " + token.symbol
                        case .fiatCurrency:
                            return AmountTextFieldViewModel.atLeastOneWhiteSpaceToKeepTextFieldHeight
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

    private let fallbackValue: Double = .zero
    private let locale: Locale = Config.locale

    var cryptoValueChanged: AnyPublisher<CryptoValueChangeEvent, Never> {
        amountChangedSubject.eraseToAnyPublisher()
    }

    let debugName: String

    init(token: EnterAmountSupportable?, debugName: String) {
        self.debugName = debugName
        self.set(token: token)
    }

    func transform(input: AmountTextFieldViewModelInput) -> AmountTextFieldViewModelOutput {
        cryptoToFiatRate
            .compactMap { $0 }
            .removeDuplicates()
            .sink { [weak self, currentPair] value in
                guard let strongSelf = self else { return }
                currentPair.value?.set(currency: value.currency)

                switch strongSelf.currentPair.value?.left {
                case .cryptoCurrency: strongSelf.recalculate(amountValue: strongSelf.cryptoRawValue)
                case .fiatCurrency: strongSelf.recalculate(amountValue: strongSelf.fiatRawValue)
                case .none: break
                }
            }.store(in: &cancelable)

        let cryptoAmountToSend = cryptoValueOrPairChanged
            .filter { $0.0.shouldChangeText }
            .map { [fallbackValue] event, currentPair -> String? in
                guard let pair = currentPair else { return nil }

                switch pair.left {
                case .cryptoCurrency:
                    let formatter = self.cryptoFormatter()
                    switch event.amount {
                    case .allFunds(let amount), .amount(let amount):
                        return formatter.string(double: amount, minimumFractionDigits: 4, maximumFractionDigits: 8)
                    case .notSet:
                        return formatter.string(double: fallbackValue, minimumFractionDigits: 4, maximumFractionDigits: 8)
                    }
                case .fiatCurrency:
                    let formatter = self.fiatFormatter(currency: pair.fiat)

                    guard let amount = self.fiatRawValue else {
                        return formatter.string(double: fallbackValue, minimumFractionDigits: 2, maximumFractionDigits: 6)
                    }

                    return formatter.string(double: amount, minimumFractionDigits: 2, maximumFractionDigits: 6)
                }
            }.eraseToAnyPublisher()

        let text = Publishers.Merge(cryptoAmountToSend, toggleFiatAndCryptoPair(trigger: input.togglePair))
            .map { $0?.droppedTrailingZeros }
            .map { $0.flatMap { $0.trimmed == "0" ? "" : $0 } }
            .eraseToAnyPublisher()

        return .init(
            text: text,
            alternativeAmount: alternativeAmount,
            currentPair: currentPair.eraseToAnyPublisher(),
            errorState: $errorState.eraseToAnyPublisher())
    }

    func set(token: EnterAmountSupportable?, switchToTokenImmediatelly: Bool = false) {
        if var currentPair = currentPair.value, !switchToTokenImmediatelly {
            //NOTE: don't switch between fiat an crypto when token changes
            self.currentPair.value = token.flatMap { currentPair.set(token: $0) }
        } else {
            self.currentPair.value = token.flatMap { AmountTextField.Pair(left: .cryptoCurrency($0), right: .fiatCurrency(cryptoToFiatRate.value.currency)) }
        }
    }

    func crypto(for string: String?) -> AmountTextFieldViewModel.FungibleAmount {
        return decimalParser.parseAnyDecimal(from: string).flatMap { self.buildAmount(from: $0.doubleValue) } ?? .amount(0)
    }

    private func buildAmount(from value: Double) -> AmountTextFieldViewModel.FungibleAmount {
        switch currentPair.value?.left {
        case .cryptoCurrency:
            return .amount(value)
        case .fiatCurrency:
            return cryptoRawValue.flatMap { .amount($0) } ?? .notSet
        case .none:
            return .notSet
        }
    }

    func toggleFiatAndCryptoPair() {
        currentPair.value?.swap()
    }

    /// Formats string value for display in text field.
    private func buildAlternativeAmountString(value: Double?, usesGroupingSeparator: Bool = false) -> String {
        guard let pair = currentPair.value, let amount = value else { return "" }

        switch pair.left {
        case .cryptoCurrency:
            //NOTE: result MUST be formatted as fiat
            let formatter = fiatFormatter(usesGroupingSeparator: usesGroupingSeparator, currency: pair.fiat)

            return formatter.string(double: amount, minimumFractionDigits: 2, maximumFractionDigits: 6).droppedTrailingZeros
        case .fiatCurrency:
            //NOTE: result MUST be formatted as crypto
            let formatter = cryptoFormatter(usesGroupingSeparator: usesGroupingSeparator)

            return formatter.string(double: amount, minimumFractionDigits: 4, maximumFractionDigits: 8).droppedTrailingZeros
        }
    }

    private func fiatFormatter(usesGroupingSeparator: Bool = false, currency: Currency) -> NumberFormatter {
        let formatter = NumberFormatter.currencyAccounting
        formatter.locale = locale
        formatter.currencyCode = currency.code
        formatter.usesGroupingSeparator = usesGroupingSeparator

        return formatter
    }

    private func cryptoFormatter(usesGroupingSeparator: Bool = false) -> NumberFormatter {
        let formatter = NumberFormatter.alternateAmount
        formatter.locale = locale
        formatter.usesGroupingSeparator = usesGroupingSeparator

        return formatter
    }

    func set(amount: AmountTextFieldViewModel.FungibleAmount) {
        switch amount {
        case .notSet:
            cryptoRawValue = nil
        case .amount(let value), .allFunds(let value):
            cryptoRawValue = value
        }

        recalculate(amountValue: cryptoRawValue, for: currentPair.value?.anyCryptoCurrency)

        amountChangedSubject.send(.manually(amount: amount))
    }

    func isValid(string: String) -> Bool {
        return decimalParser.parseAnyDecimal(from: string) != nil || string.trimmed.isEmpty
    }

    func set(string: String) {
        //NOTE: Set raw value (ethCost, dollarCost) and recalculate alternative value
        guard let pair = currentPair.value else { return }

        switch pair.left {
        case .cryptoCurrency:
            cryptoRawValue = decimalParser.parseAnyDecimal(from: string).flatMap { $0.doubleValue }

            recalculate(amountValue: cryptoRawValue)
        case .fiatCurrency:
            fiatRawValue = decimalParser.parseAnyDecimal(from: string).flatMap { $0.doubleValue }

            recalculate(amountValue: fiatRawValue)
        }

        let amount = decimalParser.parseAnyDecimal(from: string).flatMap { self.buildAmount(from: $0.doubleValue) } ?? .amount(0)

        amountChangedSubject.send(.whenTextChanged(amount: amount))
    }

    private func toggleFiatAndCryptoPair(trigger: AnyPublisher<Void, Never>) -> AnyPublisher<String?, Never> {
        return trigger.filter { [cryptoToFiatRate] _ in cryptoToFiatRate.value.value != nil }
            .map { _ -> String? in
                let string = self.buildAlternativeAmountString(value: self.alternativeAmountRawValue)
                self.toggleFiatAndCryptoPair()

                return string
            }.eraseToAnyPublisher()
    }

    ///Recalculates raw value (eth, or usd) depends on selected currency `currencyToOverride ?? currentPair.left` based on cryptoToDollarRate
    private func recalculate(amountValue: Double?, for currencyToOverride: AmountTextField.FiatOrCrypto? = nil) {
        guard let rate = cryptoToFiatRate.value.value else { return }

        switch currencyToOverride ?? currentPair.value?.left {
        case .cryptoCurrency:
            if let amount = amountValue {
                fiatRawValue = amount * rate
            } else {
                fiatRawValue = .none
            }
        case .fiatCurrency:
            if let amount = amountValue {
                cryptoRawValue = amount / rate
            } else {
                cryptoRawValue = .none
            }
        case .none:
            break
        }
    }
}

extension AmountTextFieldViewModel.FungibleAmount {
    var asAmount: FungibleAmount {
        switch self {
        case .allFunds:
            return .allFunds
        case .amount(let value):
            return .amount(value)
        case .notSet:
            return .notSet
        }
    }
}

extension AmountTextFieldViewModel {
    enum FungibleAmount {
        case amount(Double)
        case allFunds(Double)
        case notSet
    }

    enum CryptoValueChangeEvent {
        case manually(amount: AmountTextFieldViewModel.FungibleAmount)
        case whenTextChanged(amount: AmountTextFieldViewModel.FungibleAmount)

        var shouldChangeText: Bool {
            switch self {
            case .manually:
                return true
            case .whenTextChanged:
                return false
            }
        }

        var amount: AmountTextFieldViewModel.FungibleAmount {
            switch self {
            case .manually(let amount):
                return amount
            case .whenTextChanged(let amount):
                return amount
            }
        }
    }
}

extension AmountTextFieldViewModel {
    public struct CurrencyRate: Equatable {
        let value: Double?
        let currency: Currency
    }
}
