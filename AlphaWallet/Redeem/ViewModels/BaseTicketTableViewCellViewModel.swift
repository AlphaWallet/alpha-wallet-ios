// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct BaseTicketTableViewCellViewModel {
    let ticketHolder: TicketHolder

    init(
            ticketHolder: TicketHolder
    ) {
        self.ticketHolder = ticketHolder
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var status: String {
        return ""
    }

    var cellHeight: CGFloat {
        let detailsHeight = CGFloat(34)
        if ticketHolder.areDetailsVisible {
            return 120 + detailsHeight
        } else {
            return 120
        }
        }

    var checkboxImage: UIImage {
        if ticketHolder.isSelected {
            return R.image.ticket_bundle_checked()!
        } else {
            return R.image.ticket_bundle_unchecked()!
        }
    }

    var areDetailsVisible: Bool {
        return ticketHolder.areDetailsVisible
    }
}
