// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

// Override showCheckbox() to return true or false
class BaseTokenCardTableViewCell: UITableViewCell {
    static let identifier = "TokenCardTableViewCell"

    lazy var rowView = TokenCardRowView(showCheckbox: showCheckbox())

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        rowView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rowView)

        NSLayoutConstraint.activate([
            rowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rowView.topAnchor.constraint(equalTo: contentView.topAnchor),
            rowView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: BaseTokenCardTableViewCellViewModel) {
        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor

        contentView.backgroundColor = viewModel.backgroundColor

        rowView.configure(viewModel: TokenCardRowViewModel(tokenHolder: viewModel.tokenHolder))

        if showCheckbox() {
            rowView.checkboxImageView.image = viewModel.checkboxImage
        }

        rowView.stateLabel.text = "      \(viewModel.status)      "
        rowView.stateLabel.isHidden = viewModel.status.isEmpty

        rowView.areDetailsVisible = viewModel.areDetailsVisible
    }

    func showCheckbox() -> Bool {
        return true
    }
}
