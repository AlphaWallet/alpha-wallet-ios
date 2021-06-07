// Copyright © 2021 Stormbird PTE. LTD.

import UIKit

class GroupActivityViewCell: UITableViewCell {
    private let background = UIView()
    private let titleLabel = UILabel()
    private var leftEdgeConstraint: NSLayoutConstraint = .init()
    private var viewModel: GroupActivityCellViewModel?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(titleLabel)

        leftEdgeConstraint = titleLabel.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: StyleLayout.sideMargin)

        NSLayoutConstraint.activate([
            leftEdgeConstraint,
            titleLabel.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -StyleLayout.sideMargin),
            titleLabel.topAnchor.constraint(equalTo: background.topAnchor, constant: 7),
            titleLabel.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -7),

            background.anchorsConstraint(to: contentView),

            contentView.heightAnchor.constraint(equalToConstant: 80)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: GroupActivityCellViewModel) {
        self.viewModel = viewModel

        leftEdgeConstraint.constant = viewModel.leftMargin
        separatorInset = .init(top: 0, left: viewModel.leftMargin, bottom: 0, right: 0)

        selectionStyle = .none
        background.backgroundColor = viewModel.contentsBackgroundColor

        backgroundColor = viewModel.backgroundColor

        titleLabel.textColor = viewModel.titleTextColor
        titleLabel.attributedText = viewModel.title
    }
}
