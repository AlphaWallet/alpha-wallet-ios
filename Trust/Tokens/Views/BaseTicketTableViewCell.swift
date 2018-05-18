// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

// Override showCheckbox() to return true or false
class BaseTicketTableViewCell: UITableViewCell {
    static let identifier = "TicketTableViewCell"

    lazy var rowView = TicketRowView(showCheckbox: showCheckbox())

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        rowView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rowView)

        NSLayoutConstraint.activate([
            rowView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowView.topAnchor.constraint(equalTo: topAnchor),
            rowView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: BaseTicketTableViewCellViewModel) {
        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor

        contentView.backgroundColor = viewModel.backgroundColor

        rowView.configure(viewModel: .init())

        if showCheckbox() {
            rowView.checkboxImageView.image = viewModel.checkboxImage
        }

        rowView.stateLabel.text = "      \(viewModel.status)      "
        rowView.stateLabel.isHidden = viewModel.status.isEmpty

        rowView.ticketCountLabel.text = viewModel.ticketCount

        rowView.venueLabel.text = viewModel.venue

        rowView.dateLabel.text = viewModel.date

        rowView.cityLabel.text = ", \(viewModel.city)"

        rowView.categoryLabel.text = viewModel.category

        rowView.timeLabel.text = viewModel.time

        rowView.teamsLabel.text = viewModel.teams

        rowView.matchLabel.text = viewModel.match

        rowView.areDetailsVisible = viewModel.areDetailsVisible
    }

    func showCheckbox() -> Bool {
        return true
    }
}
