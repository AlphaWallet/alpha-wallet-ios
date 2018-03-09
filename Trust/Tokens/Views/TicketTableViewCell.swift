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

    let background = UIView()
    let stateLabel = UILabel()
    let ticketCountLabel = UILabel()
    let titleLabel = UILabel()
    let dateLabel = UILabel()
    let seatRangeLabel = UILabel()
    let zoneNameLabel = UILabel()
    let dateImageView = UIImageView()
    let seatRangeImageView = UIImageView()
    let zoneNameImageView = UIImageView()

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        let topRowStack = UIStackView(arrangedSubviews: [ticketCountLabel, titleLabel])
        topRowStack.axis = .horizontal
        topRowStack.spacing = 15
        topRowStack.distribution = .fill
        topRowStack.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)

        let bottomRowStack = UIStackView(arrangedSubviews: [
            dateImageView,
            dateLabel,
            .spacerWidth(7),
            seatRangeImageView,
            seatRangeLabel,
            .spacerWidth(7),
            zoneNameImageView,
            zoneNameLabel
        ])
        bottomRowStack.axis = .horizontal
        bottomRowStack.spacing = 7
        bottomRowStack.distribution = .fill
        bottomRowStack.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)

        let stackView = UIStackView(arrangedSubviews: [
            stateLabel,
            topRowStack,
            bottomRowStack
        ])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.distribution = .fill
        stackView.setContentHuggingPriority(UILayoutPriority.required, for: .vertical)
        background.addSubview(stackView)

        // TODO extract constant. Maybe StyleLayout.sideMargin
        let xMargin  = CGFloat(7)
        let yMargin  = CGFloat(5)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 21),
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -21),
            stackView.topAnchor.constraint(equalTo: background.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -16),

            background.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xMargin),
            background.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -xMargin),
            background.topAnchor.constraint(equalTo: topAnchor, constant: yMargin),
            background.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -yMargin),

            stateLabel.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: TicketTableViewCellViewModel) {
        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor

        background.backgroundColor = viewModel.contentsBackgroundColor
        background.layer.cornerRadius = 20
        background.layer.shadowRadius = 3
        background.layer.shadowColor = UIColor.black.cgColor
        background.layer.shadowOffset = CGSize(width: 0, height: 0)
        background.layer.shadowOpacity = 0.14
        background.layer.borderColor = UIColor.black.cgColor

        contentView.backgroundColor = viewModel.backgroundColor

        stateLabel.backgroundColor = viewModel.stateBackgroundColor
        stateLabel.layer.cornerRadius = 8
        stateLabel.clipsToBounds = true
        stateLabel.textColor = viewModel.stateColor
        stateLabel.font = viewModel.subtitleFont
        stateLabel.text = "      \(viewModel.status)      "
        stateLabel.isHidden = viewModel.status.isEmpty

        ticketCountLabel.textColor = viewModel.countColor
        ticketCountLabel.font = viewModel.ticketCountFont
        ticketCountLabel.text = viewModel.ticketCount

        titleLabel.textColor = viewModel.titleColor
        titleLabel.font = viewModel.titleFont
        titleLabel.text = viewModel.title

        dateLabel.textColor = viewModel.subtitleColor
        dateLabel.font = viewModel.subtitleFont
        dateLabel.text = viewModel.date

        seatRangeLabel.textColor = viewModel.subtitleColor
        seatRangeLabel.font = viewModel.subtitleFont
        seatRangeLabel.text = viewModel.seatRange

        zoneNameLabel.textColor = viewModel.subtitleColor
        zoneNameLabel.font = viewModel.subtitleFont
        zoneNameLabel.text = viewModel.zoneName

        dateImageView.image = R.image.calendar()?.withRenderingMode(.alwaysTemplate)
        seatRangeImageView.image = R.image.ticket()?.withRenderingMode(.alwaysTemplate)
        zoneNameImageView.image = R.image.category()?.withRenderingMode(.alwaysTemplate)

        dateImageView.tintColor = viewModel.iconsColor
        seatRangeImageView.tintColor = viewModel.iconsColor
        zoneNameImageView.tintColor = viewModel.iconsColor
    }
}
