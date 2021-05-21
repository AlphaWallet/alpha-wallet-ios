// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class AccountViewCell: UITableViewCell {
    private let addressLabel = UILabel()
    private let balanceLabel = UILabel()
    private let apprecation24hourLabel = UILabel()
    private let blockieImageView = BlockieImageView()

    var viewModel: AccountViewModel?
    var account: Wallet?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        separatorInset = .zero
        selectionStyle = .none
        isUserInteractionEnabled = true
        addressLabel.lineBreakMode = .byTruncatingMiddle

        let leftStackView = [
            [balanceLabel, .spacerWidth(10), apprecation24hourLabel, .spacerWidth(10)].asStackView(axis: .horizontal, distribution: .fill, spacing: 0),
            [addressLabel, .spacerWidth(10)].asStackView(axis: .horizontal, distribution: .fill, spacing: 0)
        ].asStackView(axis: .vertical, distribution: .fillProportionally, spacing: 0)

        let stackView = [blockieImageView, leftStackView].asStackView(spacing: 12, alignment: .fill)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addressLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        balanceLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        stackView.setContentHuggingPriority(.required, for: .horizontal)

        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            blockieImageView.heightAnchor.constraint(equalToConstant: 40),
            blockieImageView.widthAnchor.constraint(equalToConstant: 40),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            stackView.rightAnchor.constraint(equalTo: rightAnchor, constant: -25)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: AccountViewModel) {
        self.viewModel = viewModel

        backgroundColor = viewModel.backgroundColor

        apprecation24hourLabel.attributedText = viewModel.apprecation24hourAttributedString
        balanceLabel.attributedText = viewModel.balanceAttributedString
        addressLabel.attributedText = viewModel.addressesAttrinutedString

        accessoryType = viewModel.accessoryType

        blockieImageView.subscribable = viewModel.icon
    }
}
