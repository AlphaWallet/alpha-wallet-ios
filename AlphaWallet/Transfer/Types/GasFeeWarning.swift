//
//  GasFeeWarning.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.05.2022.
//

import Foundation

extension TransactionConfigurator {
    enum GasFeeWarning {
        case tooHighGasFee

        var description: String {
            ConfigureTransactionError.gasFeeTooHigh.localizedDescription
        }
    }
}
