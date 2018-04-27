// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct TicketTableViewCellViewModel {
    private let ticketHolder: TicketHolder

    init(
            ticketHolder: TicketHolder
    ) {
        self.ticketHolder = ticketHolder
    }

    var ticketCount: String {
        return "x\(ticketHolder.tickets.count)"
    }

    var title: String {
        return ticketHolder.name
    }

    var seatRange: String {
        return ticketHolder.seatRange
    }

    var city: String {
        return ticketHolder.city
    }

    var venue: String {
        return ticketHolder.venue
    }

    var date: String {
        //TODO Should format be localized?
        return ticketHolder.date.format("dd MMM yyyy")
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

    var cellHeight: CGFloat {
        if status.isEmpty {
		    return 120
        } else {
            return 150
        }
    }
}
