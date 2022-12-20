// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class LocaleViewCell: UITableViewCell {
    static let selectionAccessoryType: (selected: UITableViewCell.AccessoryType, unselected: UITableViewCell.AccessoryType) = (selected: .checkmark, unselected: .none)

    private let nameLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        tintColor = Configuration.Color.Semantic.appTint

        let stackView = [.spacerWidth(5), nameLabel].asStackView(axis: .horizontal)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: contentView, edgeInsets: .init(top: 7, left: DataEntry.Metric.sideMargin, bottom: 7, right: DataEntry.Metric.sideMargin)),
            stackView.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: LocaleViewModel) {
        selectionStyle = .default
        backgroundColor = viewModel.backgroundColor

        accessoryType = viewModel.accessoryType

        nameLabel.font = viewModel.localeFont
        nameLabel.text = viewModel.localeName
    }
}
