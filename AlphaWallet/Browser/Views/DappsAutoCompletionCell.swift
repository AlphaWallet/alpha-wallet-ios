// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class DappsAutoCompletionCell: UITableViewCell {
    static let identifier = "DappsAutoCompletionCell"
    let titleLabel = UILabel()
    let descriptionLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)

        let stackView = [
            titleLabel,
            descriptionLabel
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: DappsAutoCompletionCellViewModel) {
        backgroundColor = viewModel.backgroundColor
        contentView.backgroundColor = viewModel.backgroundColor

        titleLabel.font = viewModel.nameFont
        titleLabel.attributedText = viewModel.name

        descriptionLabel.font = viewModel.descriptionFont
        descriptionLabel.textColor = viewModel.descriptionColor
        descriptionLabel.text = viewModel.description
    }
}
