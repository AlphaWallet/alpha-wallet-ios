//
//  GasPriceWarning.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.05.2022.
//

import Foundation

extension TransactionConfigurator {
    enum GasPriceWarning {
        case tooHighCustomGasPrice
        case networkCongested
        case tooLowCustomGasPrice

        var shortTitle: String {
            switch self {
            case .tooHighCustomGasPrice, .networkCongested:
                return R.string.localizable.transactionConfigurationGasPriceTooHighShort()
            case .tooLowCustomGasPrice:
                return R.string.localizable.transactionConfigurationGasPriceTooLowShort()
            }
        }

        var longTitle: String {
            switch self {
            case .tooHighCustomGasPrice, .networkCongested:
                return R.string.localizable.transactionConfigurationGasPriceTooHighLong()
            case .tooLowCustomGasPrice:
                return R.string.localizable.transactionConfigurationGasPriceTooLowLong()
            }
        }

        var description: String {
            switch self {
            case .tooHighCustomGasPrice:
                return R.string.localizable.transactionConfigurationGasPriceTooHighDescription()
            case .networkCongested:
                return R.string.localizable.transactionConfigurationGasPriceCongestedDescription()
            case .tooLowCustomGasPrice:
                return R.string.localizable.transactionConfigurationGasPriceTooLowDescription()
            }
        }
    }
}
