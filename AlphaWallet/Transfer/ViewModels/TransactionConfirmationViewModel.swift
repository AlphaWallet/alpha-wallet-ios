// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt

struct TransactionConfirmationViewModel {

    private let confirmationType: ConfirmationType
    private let configuration: TransactionConfirmationConfiguration
    var openedSections: Set<Int> = []

    init(confirmationType: ConfirmationType) {
        self.confirmationType = confirmationType
        
        switch confirmationType {
        case .deposit(let address):
            let depositTransactionConfiguration = DepositTransactionConfirmationConfiguration()
            configuration = .deposit(address, depositTransactionConfiguration)
        }
    }

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

    var numberOfSections: Int {
        return configuration.numberOfSections 
    }

    func numberOfRows(in section: Int) -> Int {
        return configuration.numberOfRows(in: section)
    }

    func indexPaths(for section: Int) -> [IndexPath] {
        return []
    }

    private func expandingState(_ section: Int) -> TransactionConfirmationTableViewHeaderViewModel.HeaderViewExpandingState {
        if indexPaths(for: section).isEmpty {
            return .closed
        } else {
            let isOpened = openedSections.contains(section)
            return .opened(section: section, isOpened: isOpened)
        }
    }

    func tableHeaderViewModel(_ section: Int) -> TransactionConfirmationTableViewHeaderViewModel {
        switch configuration {
        case .deposit(let address, let configuration):
            switch configuration.sections[section] {
            case .gas:
                return .init(
                    title: R.string.localizable.tokenTransactionConfirmationDefault(),
                    placeholder: configuration.sections[section].title,
                    expandingState: expandingState(section)
                )
            case .contract:
                return .init(
                    title: address.truncateMiddle,
                    placeholder: configuration.sections[section].title,
                    expandingState: expandingState(section)
                )
            }
        }
    }
}
