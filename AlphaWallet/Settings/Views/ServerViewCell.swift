// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class ServerTableViewCell: UITableViewCell {
    static let selectionAccessoryType: (selected: UITableViewCell.AccessoryType, unselected: UITableViewCell.AccessoryType) = (selected: .checkmark, unselected: .none)

    private let nameLabel = UILabel()
    private lazy var topSeparator: UIView = UIView.spacer(backgroundColor: R.color.mike()!)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let stackView = [
            .spacer(height: 20),
            nameLabel,
            .spacer(height: 20),
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(topSeparator)
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            topSeparator.topAnchor.constraint(equalTo: contentView.topAnchor),
            topSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            topSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.anchorsConstraint(to: contentView, edgeInsets: .init(top: 0, left: StyleLayout.sideMargin, bottom: 0, right: StyleLayout.sideMargin)),
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
        nameLabel.textAlignment = .left
        nameLabel.font = viewModel.serverFont
        nameLabel.textColor = viewModel.serverColor
        nameLabel.text = viewModel.serverName
    }
}
