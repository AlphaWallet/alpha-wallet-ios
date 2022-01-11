// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct BaseTokenCardTableViewCellViewModel {
    let tokenHolder: TokenHolder
    let cellWidth: CGFloat
    let tokenView: TokenView

    var backgroundColor: UIColor {
        return GroupedTable.Color.background
    }

    var stateBackgroundColor: UIColor? {
        switch tokenHolder.status {
        case .available:
            return nil
        case .sold, .redeemed, .forSale, .transferred:
            //TODO these states are not possible yet. We can return a meaningful string now, but just leaving it "" to make clear it's not possible yet
            return nil
        case .pending:
            return UIColor(red: 235, green: 168, blue: 68)
        case .availableButDataUnavailable:
            return UIColor(red: 236, green: 110, blue: 57)
        }
    }

    var status: String {
        switch tokenHolder.status {
        case .available:
            return ""
        case .sold, .redeemed, .forSale, .transferred:
            //TODO these states are not possible yet. We can return a meaningful string now, but just leaving it "" to make clear it's not possible yet
            return ""
        case .pending:
            return R.string.localizable.transactionCellPendingTitle(preferredLanguages: Languages.preferred()).localizedUppercase
        case .availableButDataUnavailable:
            return R.string.localizable.transactionCellAvailableButDataUnavailableTitle(preferredLanguages: Languages.preferred()).localizedUppercase
        }
    }

    var checkboxImage: UIImage {
        if tokenHolder.isSelected {
            return R.image.ticket_bundle_checked()!
        } else {
            return R.image.ticket_bundle_unchecked()!
        }
    }

    var areDetailsVisible: Bool {
        return tokenHolder.areDetailsVisible
    }
}
