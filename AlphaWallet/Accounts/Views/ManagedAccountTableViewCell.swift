// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class ManagedAccountTableViewCell: UITableViewCell {
    static let identifier = "ManagedAccountTableViewCell"

    var icon = UIImageView(image: R.image.xDai())
    var addressLabel = UILabel()
    var balanceLabel = UILabel()

    var account: Wallet?
    var viewModel: AccountViewModel?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        separatorInset = .zero
        icon.contentMode = .scaleAspectFit

        addressLabel.lineBreakMode = .byTruncatingMiddle

        let leftStackView = [
            balanceLabel,
            addressLabel,
        ].asStackView(axis: .vertical, distribution: .fillProportionally, spacing: 0)

        let stackView = [icon, .spacerWidth(12), leftStackView].asStackView(spacing: 0, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        icon.setContentHuggingPriority(.required, for: .horizontal)
        addressLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        balanceLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        stackView.setContentHuggingPriority(.required, for: .horizontal)

        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 40),
            stackView.anchorsConstraint(to: contentView, edgeInsets: .init(top: 15, left: 20, bottom: 15, right: 20)),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: AccountViewModel) {
        self.viewModel = viewModel

        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor

        icon.image = viewModel.icon
        
        balanceLabel.font = viewModel.balanceFont
        balanceLabel.text = viewModel.balance

        addressLabel.font = viewModel.addressFont
        addressLabel.textColor = viewModel.addressTextColor
        addressLabel.text = viewModel.addresses
    }
}
