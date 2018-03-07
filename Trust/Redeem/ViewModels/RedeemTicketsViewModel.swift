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

    func cell(for tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            return summaryCell(for: tableView, indexPath: indexPath)
        }
        return ticketCell(for: tableView, indexPath: indexPath)
    }

    var numberOfSections: Int {
        return 2
    }

    func numberOfItems(for section: Int) -> Int {
        if section == 0 {
            return 1
        }
        return ticketHolders!.count
    }

    func height(for section: Int) -> CGFloat {
        if section == 0 {
            return 30
        }
        return 90
    }

    var title: String {
        return "Redeem Asset"
    }

    func ticketCellPressed(for indexPath: IndexPath) -> Bool {
        return indexPath.section == 1
    }

    private func summaryCell(for tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.redeemTableViewCell, for: indexPath)
        return cell!
    }

    private func ticketCell(for tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.redeemTicketCell, for: indexPath)!
        let ticketHolder = item(for: indexPath)
        cell.configure(ticketHolder: ticketHolder)
        return cell
    }

}
