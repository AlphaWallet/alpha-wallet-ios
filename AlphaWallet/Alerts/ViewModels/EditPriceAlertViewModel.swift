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
    let cryptoValue: AnyPublisher<String, Never>
}

struct EditPriceAlertViewModelOutput {
    let cryptoInitial: AnyPublisher<String, Never>
    let cryptoToFiatRate: AnyPublisher<NSDecimalNumber?, Never>
    let marketPrice: AnyPublisher<String, Never>
    let isEnabled: AnyPublisher<Bool, Never>
    let createOrUpdatePriceAlert: AnyPublisher<Result<Void, EditPriceAlertViewModel.EditPriceAlertError>, Never>
}

final class EditPriceAlertViewModel {
    private let configuration: EditPriceAlertViewModel.Configuration
    private var marketPrice: Double?
    private var cryptoValue: Double?
    private let tokensService: TokenViewModelState
    private let alertService: PriceAlertServiceType
    private var cancelable = Set<AnyCancellable>()

    var title: String { configuration.title } 
    let token: Token

    init(configuration: EditPriceAlertViewModel.Configuration, token: Token, tokensService: TokenViewModelState, alertService: PriceAlertServiceType) {
        self.configuration = configuration
        self.token = token
        self.tokensService = tokensService
        self.alertService = alertService
    }

    func transform(input: EditPriceAlertViewModelInput) -> EditPriceAlertViewModelOutput {
        let cryptoToFiatRate = Just(1)
            .map { value -> NSDecimalNumber? in NSDecimalNumber(value: value) }
            .eraseToAnyPublisher()

        let cryptoRate = tokensService.tokenViewModelPublisher(for: token)
            .map { $0?.balance.ticker?.price_usd }
            .share()
            .handleEvents(receiveOutput: { self.marketPrice = $0 })
            .map { $0.flatMap { Formatter.fiat.string(from: $0) } }
            .eraseToAnyPublisher()

        input.cryptoValue
            .map { Formatter.default.number(from: $0).flatMap { $0.doubleValue } }
            .sink(receiveValue: { self.cryptoValue = $0 })
            .store(in: &cancelable)

        let createOrUpdatePriceAlert = input.save
            .map { _ -> (crypto: Double, marketPrice: Double)? in
                guard let crypto = self.cryptoValue, let marketPrice = self.marketPrice else { return nil }
                return (crypto: crypto, marketPrice: marketPrice)
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

        var value: String {
            switch self {
            case .create:
                return String()
            case .edit(let alert):
                switch alert.type {
                case .price(_, let value):
                    return String(value)
                }
            }
        }
    }
}
