// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct BaseTicketTableViewCellViewModel {
    let ticketHolder: TokenHolder

    init(
            ticketHolder: TokenHolder
    ) {
        self.ticketHolder = ticketHolder
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var status: String {
        return ""
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
