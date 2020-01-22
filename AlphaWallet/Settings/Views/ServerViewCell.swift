// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class ServerViewCell: UITableViewCell {
    static let identifier = "ServerViewCell"
    static let selectionAccessoryType: (selected: UITableViewCell.AccessoryType, unselected: UITableViewCell.AccessoryType) = (selected: .checkmark, unselected: .none)

    private let nameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let stackView = [.spacerWidth(Table.Metric.plainLeftMargin), nameLabel].asStackView(axis: .horizontal)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: contentView, edgeInsets: .init(top: 7, left: StyleLayout.sideMargin, bottom: 7, right: StyleLayout.sideMargin)),
            stackView.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: ServerViewModel) {
        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor

        accessoryType = viewModel.accessoryType

        nameLabel.font = viewModel.serverFont
        nameLabel.text = viewModel.serverName
    }
}
