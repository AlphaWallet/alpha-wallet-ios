// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt

struct ConfirmTransactionViewModel {

    let contract: AlphaWallet.Address
    var navigationTitle: String {
        return R.string.localizable.tokenConfirmTransferTitle()
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

    var sections: [ConfirmTransactionSection] = ConfirmTransactionSection.allCases

    var numberOfSections: Int{
        return sections.count
    }

    func numberOfRows(in section: Int) -> Int {
        return 0
    }

    func viewModel(section: Int) -> ConfirmTransactionTableViewHeaderViewModel {
        let placeholder = sections[section].title

        switch sections[section] {
        case .gas:
            return .init(
                title: R.string.localizable.tokenConfirmTransactionDefault(),
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

enum ConfirmTransactionSection: Int, CaseIterable {
    case gas
    case contract

    var title: String {
        switch self {
        case .gas:
            return R.string.localizable.tokenConfirmTransactionGasTitle()
        case .contract:
            return R.string.localizable.tokenConfirmTransactionContractTitle()
        }
    }
}
