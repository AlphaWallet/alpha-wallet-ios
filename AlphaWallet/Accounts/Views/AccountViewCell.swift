// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class AccountViewCell: UITableViewCell {
    static let identifier = "AccountViewCell"

    private var icon = UIImageView()
    private var selectionImageView = UIImageView()
    private var addressLabel = UILabel()
    private var balanceLabel = UILabel()
    
    var viewModel: AccountViewModel? 
    var account: Wallet?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        separatorInset = .zero
        selectionStyle = .none
        self.isUserInteractionEnabled = true
        icon.contentMode = .scaleAspectFit
        selectionImageView.contentMode = .scaleAspectFit
        addressLabel.lineBreakMode = .byTruncatingMiddle

        let leftStackView = [
            balanceLabel,
            addressLabel,
        ].asStackView(axis: .vertical, distribution: .fillProportionally, spacing: 0)

        let stackView = [icon, .spacerWidth(12), leftStackView, .spacerWidth(20), selectionImageView].asStackView(spacing: 0, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        icon.setContentHuggingPriority(.required, for: .horizontal)
        addressLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        balanceLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        stackView.setContentHuggingPriority(.required, for: .horizontal)

        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 40),
            selectionImageView.widthAnchor.constraint(equalToConstant: 30),
            stackView.anchorsConstraint(to: contentView, edgeInsets: .init(top: 20, left: 20, bottom: 20, right: 20)),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    } 

    func configure(viewModel: AccountViewModel) {
        self.viewModel = viewModel

        backgroundColor = viewModel.backgroundColor

        icon.image = viewModel.icon
        
        balanceLabel.font = viewModel.balanceFont
        balanceLabel.text = viewModel.balance

        addressLabel.font = viewModel.addressFont
        addressLabel.textColor = viewModel.addressTextColor
        addressLabel.text = viewModel.addresses

        selectionImageView.image = viewModel.selectionIcon 
    }
}
