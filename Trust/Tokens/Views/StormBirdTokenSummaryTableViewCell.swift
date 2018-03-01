//
//  StormBirdTokenSummaryTableViewCell.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/24/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit

class StormBirdTokenSummaryTableViewCell: UITableViewCell {

    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!

    func configure(for token: TokenObject) {
        countLabel.text = totalValidTicketNumber(for: token)
        nameLabel.text = token.name.capitalized
    }

    private func totalValidTicketNumber(for token: TokenObject) -> String {
        let balance = token.balance
        let validTickets = balance.filter { $0.balance > 0 }
        return validTickets.count.toString()
    }
}
