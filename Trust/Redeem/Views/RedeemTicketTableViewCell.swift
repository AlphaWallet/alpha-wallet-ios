//
//  RedeemTicketTableViewCell.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/4/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit

class RedeemTicketTableViewCell: TicketTableViewCell {

    @IBOutlet weak var radioButton: RadioButton!

    override
    func configure(ticketHolder: TicketHolder) {
        super.configure(ticketHolder: ticketHolder)
        radioButton.isOn = ticketHolder.status == .redeemed
    }
}
