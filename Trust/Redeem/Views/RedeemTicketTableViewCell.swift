//
//  RedeemTicketTableViewCell.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/4/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit

class RedeemTicketTableViewCell: UITableViewCell {

    @IBOutlet weak var ticketView: TicketView!
    @IBOutlet weak var radioButton: RadioButton!

    func configure(ticketHolder: TicketHolder) {
        ticketView.configure(ticketHolder: ticketHolder)
        radioButton.isOn = ticketHolder.status == .redeemed
    }
}
