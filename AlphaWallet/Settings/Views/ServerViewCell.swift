// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class ServerTableViewCell: UITableViewCell {
    static let selectionAccessoryType: (selected: UITableViewCell.AccessoryType, unselected: UITableViewCell.AccessoryType) = (selected: .checkmark, unselected: .none)

    private let nameLabel = UILabel()
    private lazy var topSeparator: UIView = UIView.separator()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let stackView = [.spacerWidth(Table.Metric.plainLeftMargin), nameLabel].asStackView(axis: .horizontal)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(topSeparator)
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            topSeparator.topAnchor.constraint(equalTo: contentView.topAnchor),
            topSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            topSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            stackView.anchorsConstraint(to: contentView, edgeInsets: .init(top: 7, left: StyleLayout.sideMargin, bottom: 7, right: StyleLayout.sideMargin)),
            stackView.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: ServerTableViewCellViewModelType) {
        selectionStyle = viewModel.selectionStyle
        backgroundColor = viewModel.backgroundColor

        accessoryType = viewModel.accessoryType
        topSeparator.isHidden = viewModel.isTopSeparatorHidden
        nameLabel.font = viewModel.serverFont
        nameLabel.text = viewModel.serverName
    }
}
