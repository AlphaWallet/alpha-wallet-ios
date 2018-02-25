//
//  TicketTableViewCell.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/24/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit

class TicketTableViewCell: UITableViewCell {

    @IBOutlet weak var ticketNumberLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var venueLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var seatLabel: UILabel!
    @IBOutlet weak var zoneLabel: UILabel!

    func configure(ticketHolder: TicketHolder) {
        ticketNumberLabel.text = ticketHolder.ticketCount
        nameLabel.text = ticketHolder.name
        venueLabel.text = ticketHolder.venue
        dateLabel.text = ticketHolder.date.format("dd MMM yyyy")
        zoneLabel.text = ticketHolder.zone
        seatLabel.text = ticketHolder.seatRange
    }
}
