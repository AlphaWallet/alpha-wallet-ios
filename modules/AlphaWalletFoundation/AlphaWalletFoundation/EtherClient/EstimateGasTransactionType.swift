//
//  EstimateGasTransactionType.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 20.01.2023.
//

import Foundation

enum EstimateGasTransactionType {
    case normal(to: AlphaWallet.Address)
    case contractDeployment

    var contract: AlphaWallet.Address? {
        switch self {
        case .normal(let to):
            return to
        case .contractDeployment:
            return nil
        }
    }

    var canCapGasLimit: Bool {
        switch self {
        case .normal:
            return true
        case .contractDeployment:
            return false
        }
    }
}
