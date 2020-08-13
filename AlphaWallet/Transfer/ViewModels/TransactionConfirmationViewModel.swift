// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt

struct TransactionConfirmationViewModel {

    let contract: AlphaWallet.Address
    var navigationTitle: String {
        return R.string.localizable.tokenTransactionConfirmationTitle()
    }

    var title: String {
        return R.string.localizable.confirmPaymentConfirmButtonTitle()
    }

    var confirmButtonTitle: String {
        return R.string.localizable.confirmPaymentConfirmButtonTitle()
    }

    var backgroundColor: UIColor {
        return R.color.white()!
    }

    var sections: [TransactionConfirmationSection] = TransactionConfirmationSection.allCases

    var numberOfSections: Int {
        return sections.count
    }

    func numberOfRows(in section: Int) -> Int {
        return 0
    }

    func viewModel(section: Int) -> TransactionConfirmationTableViewHeaderViewModel {
        let placeholder = sections[section].title

        switch sections[section] {
        case .gas:
            return .init(
                title: R.string.localizable.tokenTransactionConfirmationDefault(),
                placeholder: placeholder
            )
        case .contract:
            return .init(
                title: contract.truncateMiddle,
                placeholder: placeholder
            )
        }
    }
}

enum TransactionConfirmationSection: Int, CaseIterable {
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
