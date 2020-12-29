// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

class WalletConnectSessionCell: UITableViewCell {
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

    func configure(viewModel: WalletConnectSessionCellViewModel) {
        selectionStyle = .default
        backgroundColor = viewModel.backgroundColor
        nameLabel.font = viewModel.nameFont
        nameLabel.text = viewModel.name
    }
}
