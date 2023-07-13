//
//  CurrencyService.swift
//  Alamofire
//
//  Created by Vladyslav Shepitko on 09.07.2022.
//

import Combine

public protocol CurrencyServiceStorage {
    var currency: Currency { get set }
}

public final class CurrencyService {
    private var storage: CurrencyServiceStorage

    public var availableCurrencies: [Currency] {
        return [.USD, .EUR, .GBP, .AUD, .UAH, .CAD, .CNY, .JPY, .NZD, .PLN, .SGD, .TRY, .TWD]
    }

    @Published public private (set) var currency: Currency

    public init(storage: CurrencyServiceStorage) {
        self.storage = storage
        if !Features.current.isAvailable(.isChangeCurrencyEnabled) {
            self.storage.currency = .default
        }
        currency = storage.currency
    }

    public func set(currency: Currency) {
        guard Features.current.isAvailable(.isChangeCurrencyEnabled) else { return }

        storage.currency = currency
        self.currency = currency
    }
}

extension Config: CurrencyServiceStorage { }
