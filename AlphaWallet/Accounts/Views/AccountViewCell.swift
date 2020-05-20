// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol AccountViewCellDelegate: class {
    func accountViewCell(_ cell: AccountViewCell, didTapInfoViewForAccount _: Wallet)
}

class AccountViewCell: UITableViewCell {
    static let identifier = "AccountViewCell"

    private var icon = UIImageView()
    private var selectionImageView = UIImageView()
    private var addressLabel = UILabel()
    private var balanceLabel = UILabel()
    
    var viewModel: AccountViewModel?
    weak var delegate: AccountViewCellDelegate?
    var account: Wallet?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        separatorInset = .zero
        selectionStyle = .none
        
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
            stackView.anchorsConstraint(to: contentView, edgeInsets: .init(top: 15, left: 20, bottom: 15, right: 20)),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func optionsSelected() {
        guard let account = account else { return }
        delegate?.accountViewCell(self, didTapInfoViewForAccount: account)
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
