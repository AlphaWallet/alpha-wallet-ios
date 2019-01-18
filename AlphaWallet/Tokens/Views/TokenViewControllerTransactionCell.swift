// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class TokenViewControllerTransactionCell: UITableViewCell {
    static let identifier = "TokenViewControllerTransactionCell"

    private let dateLabel = UILabel()
    private let typeLabel = UILabel()
    private let amountLabel = UILabel()
    private let typeImageView = UIImageView()
    private let accessoryImageView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let row0StackView = [.spacerWidth(30), dateLabel, .spacerWidth(30)].asStackView(alignment: .center)
        let row1StackView = [.spacerWidth(30), typeImageView, .spacerWidth(7), typeLabel, amountLabel, .spacerWidth(10), accessoryImageView, .spacerWidth(30)].asStackView(alignment: .center)

        let mainStackView = [
            .spacer(height: 14),
            row0StackView,
            .spacer(height: 14),
            row1StackView,
            .spacer(height: 14),
        ].asStackView(axis: .vertical)
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStackView)

        NSLayoutConstraint.activate([
            accessoryImageView.widthAnchor.constraint(equalToConstant: 10),
            accessoryImageView.widthAnchor.constraint(equalTo: accessoryImageView.heightAnchor),

            typeImageView.widthAnchor.constraint(equalToConstant: 12),
            typeImageView.widthAnchor.constraint(equalTo: typeImageView.heightAnchor),

            mainStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            mainStackView.topAnchor.constraint(equalTo: topAnchor),
            mainStackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: TokenViewControllerTransactionCellViewModel) {
        separatorInset = .zero
        layoutMargins = .zero

        dateLabel.textColor = viewModel.dateColor
        dateLabel.font = viewModel.dateFont
        dateLabel.text = viewModel.date
        
        amountLabel.attributedText = viewModel.value

        typeLabel.text = viewModel.type
        typeLabel.textColor = viewModel.typeColor
        typeLabel.font = viewModel.typeFont

        typeImageView.image = viewModel.typeImage
        typeImageView.contentMode = .scaleAspectFill

        accessoryImageView.contentMode = .scaleAspectFill
        accessoryImageView.image = viewModel.accessoryImage
    }

    //Really should not happen, but let's just be careful
    func configureEmpty() {
        dateLabel.text = ""
        amountLabel.text = ""
        typeLabel.text = ""
        typeImageView.image = nil
        accessoryImageView.image = nil
    }
}

