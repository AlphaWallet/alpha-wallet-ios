// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Macaw

// Override showCheckbox() to return true or false
class BaseTicketTableViewCell: UITableViewCell {
    static let identifier = "TicketTableViewCell"

    lazy var rowView = TicketRowView(showCheckbox: showCheckbox())
    //kkk should probably be in TicketRowView instead
    let svgView = SVGView()

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        rowView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rowView)

        svgView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(svgView)

        NSLayoutConstraint.activate([
            rowView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowView.topAnchor.constraint(equalTo: topAnchor),
            rowView.bottomAnchor.constraint(equalTo: bottomAnchor),

            svgView.widthAnchor.constraint(equalToConstant: 60),
            svgView.trailingAnchor.constraint(equalTo: trailingAnchor),
            svgView.topAnchor.constraint(equalTo: topAnchor),
            svgView.heightAnchor.constraint(equalToConstant: 60)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: BaseTicketTableViewCellViewModel) {
        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor

        contentView.backgroundColor = viewModel.backgroundColor

        rowView.configure(viewModel: .init(ticketHolder: viewModel.ticketHolder))

        if showCheckbox() {
            rowView.checkboxImageView.image = viewModel.checkboxImage
        }

        rowView.stateLabel.text = "      \(viewModel.status)      "
        rowView.stateLabel.isHidden = viewModel.status.isEmpty

        rowView.areDetailsVisible = viewModel.areDetailsVisible

        //kkk don't always show this. Only for tokens that has asset definition which say it has an image
        svgView.backgroundColor = viewModel.backgroundColor
        //kkk need to know if it's svg or png, etc?
        if let node = viewModel.assetImageNode {
            svgView.node = node
        }
    }

    func showCheckbox() -> Bool {
        return true
    }
}
