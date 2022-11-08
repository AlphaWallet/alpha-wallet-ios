//
//  CurrencyService.swift
//  Alamofire
//
//  Created by Vladyslav Shepitko on 08.11.2022.
//

import Combine

public final class CurrencyService {
    public var availableCurrencies: [Currency] {
        return [.USD, .EUR, .GBP, .AUD, .UAH, .CAD, .CNY, .JPY, .NZD, .PLN, .SGD, .TRY, .TWD]
    }

    public var currency: Currency {
        get { Config.currency }
        set { Config.currency = newValue }
    }

    public init() {

    }
}
