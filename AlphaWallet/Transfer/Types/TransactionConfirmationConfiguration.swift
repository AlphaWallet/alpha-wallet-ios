//
//  TransactionConfirmationConfiguration.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.07.2020.
//

import UIKit

enum TransactionConfirmationConfiguration {
    case deposit(AlphaWallet.Address, DepositTransactionConfirmationConfiguration)

    var numberOfSections: Int {
        switch self {
        case .deposit(_, let viewModel):
            return viewModel.sections.count
        }
    }

    func numberOfRows(in section: Int) -> Int {
        switch self {
        case .deposit:
            return 0
        }
    }
}

struct DepositTransactionConfirmationConfiguration {

    let sections: [Section] = [.contract, .gas]

    enum Section: Int, CaseIterable {
        case gas
        case contract

        var title: String {
            switch self {
            case .gas:
                return R.string.localizable.tokenTransactionConfirmationGasTitle()
            case .contract:
                return R.string.localizable.tokenTransactionConfirmationContractTitle()
            }
        }
    }
}
