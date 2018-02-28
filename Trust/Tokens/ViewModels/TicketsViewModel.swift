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

    let token: TokenObject
    let ticketHolders: [TicketHolder]

    func item(for indexPath: IndexPath) -> TicketHolder {
        return ticketHolders[indexPath.row]
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
        return ticketHolders.count
    }

    func height(for section: Int) -> CGFloat {
        if section == 0 {
            return 50
        }
        return 90
    }

    func ticketCellPressed(for indexPath: IndexPath) -> Bool {
        return indexPath.section == 1
    }

    private func summaryCell(for tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StormBirdTokenSummaryTableViewCell", for: indexPath) as! StormBirdTokenSummaryTableViewCell
        cell.configure(for: token)
        return cell
    }

    private func ticketCell(for tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TicketCell", for: indexPath) as! TicketTableViewCell
        let ticketHolder = item(for: indexPath)
        cell.configure(ticketHolder: ticketHolder)
        return cell
    }
}
