//
//  TicketTableViewCell.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/24/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit

class TicketTableViewCell: UITableViewCell {
    @IBOutlet weak var ticketView: TicketView!

    func configure(ticketHolder: TicketHolder) {
        ticketView.configure(ticketHolder: ticketHolder)
    }
}
