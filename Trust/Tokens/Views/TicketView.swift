//
//  TicketView.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/5/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit

@IBDesignable
class TicketView: UIView {

    let nibName = "TicketView"
    var contentView: UIView?

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

extension TicketView {
    override
    func awakeFromNib() {
        super.awakeFromNib()
        nibSetup()
    }

    override
    func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        nibSetup()
        contentView?.prepareForInterfaceBuilder()
    }

    func nibSetup() {
        guard let view = loadViewFromNib() else { return }
        view.frame = bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(view)
        contentView = view
    }

    func loadViewFromNib() -> UIView? {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: nibName, bundle: bundle)
        return nib.instantiate(withOwner: self, options: nil).first as? UIView
    }

}
