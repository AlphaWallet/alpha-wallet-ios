// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct TicketTableViewCellViewModel {
    private let ticketHolder: TokenHolder

    init(
            ticketHolder: TokenHolder
    ) {
        self.ticketHolder = ticketHolder
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var status: String {
        switch ticketHolder.status {
        case .available:
            return ""
        case .sold:
            return R.string.localizable.aWalletTicketTokenBundleStatusSoldTitle()
        case .forSale:
            return R.string.localizable.aWalletTicketTokenBundleStatusForSaleTitle()
        case .transferred:
            return R.string.localizable.aWalletTicketTokenBundleStatusTransferredTitle()
        case .redeemed:
            return R.string.localizable.aWalletTicketTokenBundleStatusRedeemedTitle()
        }
    }
}
