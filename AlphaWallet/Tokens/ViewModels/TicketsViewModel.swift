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
    var ticketHolders: [TokenHolder]

    init(token: TokenObject) {
        self.token = token
        self.ticketHolders = TokenAdaptor(token: token).getTicketHolders()
    }

    func item(for indexPath: IndexPath) -> TokenHolder {
        return ticketHolders[indexPath.row]
    }

    func numberOfItems(for section: Int) -> Int {
        return ticketHolders.count
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

    func toggleDetailsVisible(for indexPath: IndexPath) -> [IndexPath] {
        let ticketHolder = item(for: indexPath)
        var changed = [indexPath]
        if ticketHolder.areDetailsVisible {
            ticketHolder.areDetailsVisible = false
        } else {
            for (i, each) in ticketHolders.enumerated() where each.areDetailsVisible {
                each.areDetailsVisible = false
                changed.append(.init(row: i, section: indexPath.section))
            }
            ticketHolder.areDetailsVisible = true
        }
        return changed
    }
}
