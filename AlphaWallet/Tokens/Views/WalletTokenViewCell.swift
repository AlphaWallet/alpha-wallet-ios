//
//  WalletTokenViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.06.2021.
//

import UIKit

protocol WalletTokenViewCellDelegate: AnyObject {
    func cell(_ cell: WalletTokenViewCell, switchStateChanged isOn: Bool)
}

class WalletTokenViewCell: UITableViewCell {
    private let background = UIView()
    private let titleLabel = UILabel()
    private let cryptoValueLabel = UILabel()
    private let switchView: UIButton = {
        let switchView = UIButton(type: .custom)
        switchView.setImage(R.image.switchOff(), for: .normal)
        switchView.setImage(R.image.switchOn(), for: .selected)
        switchView.translatesAutoresizingMaskIntoConstraints = false
        return switchView
    }()
    private var viewsWithContent: [UIView] {
        [titleLabel, cryptoValueLabel]
    }

    private var tokenIconImageView: TokenImageView = {
        let imageView = TokenImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    var isOn: Bool {
        get { return switchView.isSelected }
        set { switchView.isSelected = newValue }
    }

    private var blockChainTagLabel = BlockchainTagLabel()
    weak var delegate: WalletTokenViewCellDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            tokenIconImageView,
            [cryptoValueLabel, titleLabel, UIView.spacerWidth(flexible: true)].asStackView(spacing: 5), .spacerWidth(flexible: true), switchView
        ].asStackView(axis: .horizontal, spacing: 16, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)
        switchView.addTarget(self, action: #selector(switchChanged), for: .touchUpInside)
        NSLayoutConstraint.activate([
            tokenIconImageView.heightAnchor.constraint(equalToConstant: 32),
            tokenIconImageView.widthAnchor.constraint(equalToConstant: 32),
            stackView.anchorsConstraint(to: background, edgeInsets: .init(top: 16, left: 20, bottom: 16, right: 16)),
            background.topAnchor.constraint(equalTo: contentView.topAnchor),
            background.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            background.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            background.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
    
    @objc private func switchChanged(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        delegate?.cell(self, switchStateChanged: sender.isSelected)
    }

    func configure(viewModel: WalletTokenViewCellViewModel) {
        selectionStyle = .none

        backgroundColor = Colors.clear
        background.backgroundColor = viewModel.backgroundColor
        background.cornerRadius = 8
        background.layer.shadowColor = Colors.lightGray.cgColor
        background.layer.shadowRadius = 2
        background.layer.shadowOffset = .zero
        background.layer.shadowOpacity = 0.6
        titleLabel.attributedText = viewModel.titleAttributedString
        titleLabel.baselineAdjustment = .alignCenters

        cryptoValueLabel.attributedText = viewModel.cryptoValueAttributedString

        viewsWithContent.forEach {
            $0.alpha = viewModel.alpha
        }
        tokenIconImageView.subscribable = viewModel.iconImage
        tokenIconImageView.borderWidth = 1
        tokenIconImageView.borderColor = Colors.gray
        tokenIconImageView.layer.cornerRadius = tokenIconImageView.frame.size.height / 2
        blockChainTagLabel.configure(viewModel: viewModel.blockChainTagViewModel)
        switchView.isSelected = viewModel.visible
    }
}
