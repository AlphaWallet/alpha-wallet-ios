//
//  TicketsViewModel.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/24/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit

struct TicketsViewModel {

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
