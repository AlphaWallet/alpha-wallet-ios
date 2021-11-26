// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class AccountViewCell: UITableViewCell {
    private let addressLabel = UILabel()
    let apprecation24hourLabel = UILabel()
    let balanceLabel = UILabel()
    private let blockieImageView = BlockieImageView(size: .init(width: 40, height: 40))

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
        
        let menuButton = UIButton(type: .custom)
        menuButton.setImage(R.image.toolbarMenu(), for: .normal)
        menuButton.tintColor = Colors.headerThemeColor
        
        let vwImgStatus = UIImageView()
        vwImgStatus.image = R.image.blueTick()

        let stackView = [menuButton, blockieImageView, leftStackView, vwImgStatus, .spacerWidth(0)].asStackView(spacing: 12, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let vwContainer = UIView()
        vwContainer.cornerRadius = 8
        vwContainer.clipsToBounds = true
        vwContainer.backgroundColor = Colors.appWhite
        contentView.addSubview(vwContainer)
        vwContainer.translatesAutoresizingMaskIntoConstraints = false
        
        vwContainer.addSubview(stackView)

        NSLayoutConstraint.activate([
            vwContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            vwContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            vwContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            vwContainer.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -20),
            
            stackView.topAnchor.constraint(equalTo: vwContainer.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: vwContainer.bottomAnchor, constant: -10),
            stackView.leadingAnchor.constraint(equalTo: vwContainer.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: vwContainer.trailingAnchor, constant: -10),

        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: AccountViewModel) {
        self.viewModel = viewModel

        backgroundColor = Colors.appBackground

        addressLabel.attributedText = viewModel.addressesAttrinutedString

        accessoryType = .none

        blockieImageView.subscribable = viewModel.icon
    }
}
