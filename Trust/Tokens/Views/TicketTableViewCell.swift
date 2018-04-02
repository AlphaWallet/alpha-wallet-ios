//
//  TicketTableViewCell.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/24/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import UIKit

class TicketTableViewCell: UITableViewCell {
    static let identifier = "TicketTableViewCell"

	let rowView = TicketRowView()

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        rowView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rowView)

        NSLayoutConstraint.activate([
            rowView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowView.topAnchor.constraint(equalTo: topAnchor),
            rowView.bottomAnchor.constraint(equalTo:bottomAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: TicketTableViewCellViewModel) {
        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor
		contentView.backgroundColor = viewModel.backgroundColor

        rowView.configure(viewModel: .init())

        rowView.stateLabel.text = "      \(viewModel.status)      "
        rowView.stateLabel.isHidden = viewModel.status.isEmpty

        rowView.ticketCountLabel.text = viewModel.ticketCount

        rowView.titleLabel.text = viewModel.title

        rowView.dateLabel.text = viewModel.date

        rowView.seatRangeLabel.text = viewModel.seatRange

        rowView.zoneNameLabel.text = viewModel.zoneName
    }
}
