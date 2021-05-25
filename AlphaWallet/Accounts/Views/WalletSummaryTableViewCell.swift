//
//  WalletSummaryHeaderView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.05.2021.
//

import UIKit

class WalletSummaryTableViewCell: UITableViewCell {
    private let apprecation24HoursLabel = UILabel()
    private let balanceLabel = UILabel()

    var viewModel: WalletSummaryTableViewCellViewModel?
    var walletSummarySubscriptionKey: Subscribable<WalletSummary>.SubscribableKey?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        separatorInset = .zero
        selectionStyle = .none
        isUserInteractionEnabled = true
        apprecation24HoursLabel.lineBreakMode = .byTruncatingMiddle

        let leftStackView = [
            balanceLabel,
            apprecation24HoursLabel,
        ].asStackView(axis: .vertical, distribution: .fillProportionally, spacing: 0)

        let stackView = [leftStackView].asStackView(spacing: 12, alignment: .fill)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        apprecation24HoursLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        balanceLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        stackView.setContentHuggingPriority(.required, for: .horizontal)

        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: contentView, edgeInsets: .init(top: 20, left: 20, bottom: 20, right: 0)),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: WalletSummaryTableViewCellViewModel) {
        self.viewModel = viewModel

        backgroundColor = viewModel.backgroundColor

        balanceLabel.attributedText = viewModel.balanceAttributedString
        apprecation24HoursLabel.attributedText = viewModel.apprecation24HoursAttributedString

        accessoryType = viewModel.accessoryType
    }
}
