// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class AccountViewCell: UITableViewCell {
    private let addressLabel = UILabel()
    let apprecation24hourLabel = UILabel()
    let balanceLabel = UILabel()
    private let blockieImageView = BlockieImageView()

    var viewModel: AccountViewModel?
    var account: Wallet?
    var balanceSubscribtionKey: Subscribable<WalletBalance>.SubscribableKey?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        separatorInset = .zero
        selectionStyle = .none
        isUserInteractionEnabled = true
        addressLabel.lineBreakMode = .byTruncatingMiddle

        let leftStackView = [
            [balanceLabel, apprecation24hourLabel].asStackView(spacing: 10),
            addressLabel
        ].asStackView(axis: .vertical)

        let stackView = [blockieImageView, leftStackView, .spacerWidth(10)].asStackView(spacing: 12, alignment: .top)
        stackView.translatesAutoresizingMaskIntoConstraints = false

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

        addressLabel.attributedText = viewModel.addressesAttrinutedString

        accessoryType = viewModel.accessoryType

        blockieImageView.subscribable = viewModel.icon
    }
}
