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

    var zoneName: String {
        return ticketHolder.zone
    }

    var date: String {
        //TODO Should format be localized?
        return ticketHolder.date.format("dd MMM yyyy")
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var titleColor: UIColor {
        return Colors.appText
    }

    var countColor: UIColor {
        if ticketHolder.status == .available {
            return Colors.appHighlightGreen
        } else {
            return UIColor(red: 155, green: 155, blue: 155)
        }
    }

    var subtitleColor: UIColor {
        return UIColor(red: 112, green: 112, blue: 112)
    }

    var iconsColor: UIColor {
        if ticketHolder.status == .available {
            return Colors.appBackground
        } else {
            return UIColor(red: 151, green: 151, blue: 151)
        }
    }

    var ticketCountFont: UIFont {
        return Fonts.bold(size: 21)!
    }

    var titleFont: UIFont {
        return Fonts.light(size: 21)!
    }

    var subtitleFont: UIFont {
        return Fonts.semibold(size: 15)!
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

    var stateBackgroundColor: UIColor {
        return UIColor(red: 151, green: 151, blue: 151)
    }

    var stateColor: UIColor {
        return .white
    }

    var cellHeight: CGFloat {
        if status.isEmpty {
            return 113
        } else {
            return 143
        }
    }
}
