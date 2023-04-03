//
//  EditPriceAlertViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import UIKit
import AlphaWalletFoundation
import Combine

struct EditPriceAlertViewModelInput {
    let willAppear: AnyPublisher<Void, Never>
    let save: AnyPublisher<Void, Never>
    let amountToSend: AnyPublisher<AmountTextFieldViewModel.FungibleAmount, Never>
}

struct EditPriceAlertViewModelOutput {
    let cryptoInitial: AnyPublisher<Double, Never>
    let cryptoToFiatRate: AnyPublisher<AmountTextFieldViewModel.CurrencyRate, Never>
    let marketPrice: AnyPublisher<String, Never>
    let isEnabled: AnyPublisher<Bool, Never>
    let createOrUpdatePriceAlert: AnyPublisher<Result<Void, EditPriceAlertViewModel.EditPriceAlertError>, Never>
}

final class EditPriceAlertViewModel {
    private let configuration: EditPriceAlertViewModel.Configuration
    private var rate: CurrencyRate?
    private var cryptoValue: Double?
    private let tokensService: TokensProcessingPipeline
    private let alertService: PriceAlertServiceType
    private var cancelable = Set<AnyCancellable>()
    private let currencyService: CurrencyService

    var title: String { configuration.title } 
    let token: Token

    init(configuration: EditPriceAlertViewModel.Configuration, token: Token, tokensService: TokensProcessingPipeline, alertService: PriceAlertServiceType, currencyService: CurrencyService) {
        self.currencyService = currencyService
        self.configuration = configuration
        self.token = token
        self.tokensService = tokensService
        self.alertService = alertService
    }

    func transform(input: EditPriceAlertViewModelInput) -> EditPriceAlertViewModelOutput {
        let cryptoToFiatRate = Just(1)
            .map { [currencyService] in AmountTextFieldViewModel.CurrencyRate(value: $0, currency: currencyService.currency) }
            .eraseToAnyPublisher()

        let cryptoRate = tokensService.tokenViewModelPublisher(for: token)
            .map { $0.flatMap { $0.balance.ticker.flatMap { CurrencyRate(currency: $0.currency, value: $0.price_usd) } } }
            .share()
            .handleEvents(receiveOutput: { self.rate = $0 })
            .map { $0.flatMap { NumberFormatter.fiatShort(currency: $0.currency).string(double: $0.value) } }

        input.amountToSend
            .compactMap { amount -> Double? in
                switch amount {
                case .amount(let value): return value
                case .notSet, .allFunds: return nil
                }
            }.sink(receiveValue: { self.cryptoValue = $0 })
            .store(in: &cancelable)

        let createOrUpdatePriceAlert = input.save
            .map { _ -> (crypto: Double, marketPrice: Double)? in
                guard let crypto = self.cryptoValue, let rate = self.rate else { return nil }
                return (crypto: crypto, marketPrice: rate.value)
            }.map { [alertService, token, configuration] pair -> Result<Void, EditPriceAlertError> in
                guard let pair = pair else { return .failure(.cryptoOrMarketPriceNotFound) }

                switch configuration {
                case .create:
                    let alert: PriceAlert = .init(type: .init(value: pair.crypto, marketPrice: pair.marketPrice), token: token, isEnabled: true)
                    guard alertService.add(alert: alert) else { return .failure(.alertAlreadyExists) }
                    return .success(())
                case .edit(let alert):
                    alertService.update(alert: alert, update: .value(value: pair.crypto, marketPrice: pair.marketPrice))
                    return .success(())
                }
            }.eraseToAnyPublisher()

        let marketPrice = cryptoRate
            .map { "Current price: \($0 ?? "-")" }
            .eraseToAnyPublisher()

        let isEnabled = cryptoRate
            .map { $0 != nil }
            .eraseToAnyPublisher()

        let cryptoInitial = input.willAppear
            .map { _ in self.configuration.value }
            .eraseToAnyPublisher()

        return .init(cryptoInitial: cryptoInitial, cryptoToFiatRate: cryptoToFiatRate, marketPrice: marketPrice, isEnabled: isEnabled, createOrUpdatePriceAlert: createOrUpdatePriceAlert)
    }
}

extension EditPriceAlertViewModel {
    enum EditPriceAlertError: Error {
        case cryptoOrMarketPriceNotFound
        case alertAlreadyExists
    }

    enum Configuration {
        case create
        case edit(PriceAlert)

        var title: String {
            switch self {
            case .create:
                return R.string.localizable.priceAlertSetNewAlert()
            case .edit:
                return R.string.localizable.priceAlertEdit()
            }
        }

        var value: Double {
            switch self {
            case .create:
                return 0
            case .edit(let alert):
                switch alert.type {
                case .price(_, let value):
                    return value
                }
            }
        }
    }
}
