//
//  EditPriceAlertViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import UIKit

enum EdiPricetAlertViewModelConfiguration {
    case create
    case edit(PriceAlert)

    var navigationTitle: String {
        switch self {
        case .create:
            return "Set New Alert"
        case .edit:
            return "Edit Alert"
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

struct EditPriceAlertViewModel {
    let configuration: EdiPricetAlertViewModelConfiguration
    let tokenObject: TokenObject
    var backgroundColor: UIColor = Colors.appWhite
    var navigationTitle: String { configuration.navigationTitle }
    private (set) var marketPrice: Double?

    let value: String

    init(configuration: EdiPricetAlertViewModelConfiguration, tokenObject: TokenObject) {
        self.configuration = configuration
        self.tokenObject = tokenObject
        value = configuration.value
    }

    mutating func set(marketPrice: Double?) {
        self.marketPrice = marketPrice
    }

    var headerTitle: String = "Enter target price".uppercased()
    var setAlertTitle: String = "Set Alert"
    var marketPriceString: String {
        let value: String = {
            guard let value = marketPrice else { return "-" }
            return NumberFormatter.usd(format: .fiatFormat).string(from: value) ?? "-"
        }()

        return "Current price: \(value)"
    }

    var isEditingAvailable: Bool {
        guard let value = marketPrice else { return false }
        return NumberFormatter.usd(format: .fiatFormat).string(from: value) != nil
    }
}
