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
        let detailsHeight = CGFloat(34)
        if status.isEmpty {
            if ticketHolder.areDetailsVisible {
                return 120 + detailsHeight
            } else {
                return 120
            }
        } else {
            if ticketHolder.areDetailsVisible {
                return 150 + detailsHeight
            } else {
                return 150
            }
        }
    }
}
