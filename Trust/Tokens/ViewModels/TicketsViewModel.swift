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
            return 50
        }
        return 90
    }

    var title: String {
        return "Use Token"
    }

    func ticketCellPressed(for indexPath: IndexPath) -> Bool {
        return indexPath.section == 1
    }

    private func summaryCell(for tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.stormBirdTokenSummaryTableViewCell, for: indexPath)!
        cell.configure(for: token)
        return cell
    }

    private func ticketCell(for tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.ticketCell, for: indexPath)!
        let ticketHolder = item(for: indexPath)
        cell.configure(ticketHolder: ticketHolder)
        return cell
    }
}
