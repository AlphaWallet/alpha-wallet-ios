//
//  GasLimitWarning.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.05.2022.
//

import Foundation

extension TransactionConfigurator {
    public enum GasLimitWarning {
        case tooHighCustomGasLimit

        public var description: String {
            ConfigureTransactionError.gasLimitTooHigh.localizedDescription
        }
    }
}
