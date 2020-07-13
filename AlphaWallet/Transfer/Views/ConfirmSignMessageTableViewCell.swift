// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class ConfirmSignMessageTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: ConfirmSignMessageTableViewCellViewModel) {
        contentView.backgroundColor = viewModel.backgroundColor
        selectionStyle = .none

        textLabel?.font = viewModel.nameTextFont

        detailTextLabel?.numberOfLines = 0
        detailTextLabel?.font = viewModel.valueTextFont
        detailTextLabel?.textColor = viewModel.valueTextColor

        textLabel?.text = viewModel.name
        detailTextLabel?.text = viewModel.value
    }
}

class ConfirmTransactionTableViewCell: UITableViewCell {

    private let titleLabel: UILabel = {
        let titleLabel = UILabel(frame: .zero)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = Fonts.regular(size: 18)
        titleLabel.textAlignment = .left
        titleLabel.textColor = Colors.darkGray

        return titleLabel
    }()

    private let subTitleLabel: UILabel = {
        let subTitleLabel = UILabel(frame: .zero)
        subTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subTitleLabel.textAlignment = .left
        subTitleLabel.textColor = Colors.black
        subTitleLabel.font = Fonts.light(size: 15)
        subTitleLabel.numberOfLines = 0

        return subTitleLabel
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let textLabelsStackView = [
            titleLabel,
            subTitleLabel,
        ].asStackView(axis: .vertical)

        textLabelsStackView.translatesAutoresizingMaskIntoConstraints = false
        textLabelsStackView.isLayoutMarginsRelativeArrangement = true

        contentView.addSubview(textLabelsStackView)

        NSLayoutConstraint.activate([
            textLabelsStackView.anchorsConstraint(to: contentView, edgeInsets: .init(top: 8, left: 24, bottom: 8, right: 24)),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: ConfirmTransactionTableViewCellViewModel) {
        titleLabel.text = viewModel.title
        subTitleLabel.text = viewModel.subTitle
    }
}
