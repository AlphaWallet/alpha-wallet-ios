//
//  EditPriceAlertViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import UIKit
import AlphaWalletFoundation

enum EdiPricetAlertViewModelConfiguration {
    case create
    case edit(PriceAlert)

    var navigationTitle: String {
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

struct EditPriceAlertViewModel {
    let configuration: EdiPricetAlertViewModelConfiguration
    let token: Token
    var backgroundColor: UIColor = Colors.appWhite
    var navigationTitle: String { configuration.navigationTitle }
    private (set) var marketPrice: Double?

    let value: String

    init(configuration: EdiPricetAlertViewModelConfiguration, token: Token) {
        self.configuration = configuration
        self.token = token
        value = configuration.value
    }

    mutating func set(marketPrice: Double?) {
        self.marketPrice = marketPrice
    }

    var headerTitle: String = R.string.localizable.priceAlertEnterTargetPrice().uppercased()
    var setAlertTitle: String = R.string.localizable.priceAlertSet()
    var marketPriceString: String {
        let value: String = {
            guard let value = marketPrice else { return "-" }
            return Formatter.fiat.string(from: value) ?? "-"
        }()

        return "Current price: \(value)"
    }

    var isEditingAvailable: Bool {
        guard let value = marketPrice else { return false }
        return Formatter.fiat.string(from: value) != nil
    }
}
