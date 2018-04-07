// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct TransferTicketsViewModel {

    var token: TokenObject
    var ticketHolders: [TicketHolder]?

    init(token: TokenObject) {
        self.token = token
        self.ticketHolders = TicketAdaptor.getTicketHolders(for: token)
    }

    func item(for indexPath: IndexPath) -> TicketHolder {
        return ticketHolders![indexPath.row]
    }

    func numberOfItems(for section: Int) -> Int {
        return ticketHolders!.count
    }

    func height(for section: Int) -> CGFloat {
        return 90
    }

    var title: String {
        return R.string.localizable.aWalletTicketTokenTransferSelectTicketsTitle ()
    }

    var buttonTitleColor: UIColor {
        return Colors.appWhite
    }

    var buttonBackgroundColor: UIColor {
        return Colors.appHighlightGreen
    }

    var buttonFont: UIFont {
        return Fonts.regular(size: 20)!
    }
}
