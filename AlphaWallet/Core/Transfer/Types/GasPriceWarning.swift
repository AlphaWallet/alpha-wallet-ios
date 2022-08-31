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
    }
}
