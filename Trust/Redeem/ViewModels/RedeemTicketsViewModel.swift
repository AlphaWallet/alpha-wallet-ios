//
//  RedeemTicketsViewModel.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/4/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit

struct RedeemTicketsViewModel {

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
        return R.string.localizable.aWalletTicketTokenRedeemSelectTicketsTitle ()
    }

    private func summaryCell(for tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.redeemTableViewCell, for: indexPath)
        return cell!
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
