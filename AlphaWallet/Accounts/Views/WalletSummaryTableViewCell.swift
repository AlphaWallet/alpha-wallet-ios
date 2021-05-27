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

struct WalletSummaryTableViewCellViewModel {
    private let server: RPCServer
    let walletBalance: Balance?

    init(walletBalance: Balance?, server: RPCServer) {
        self.walletBalance = walletBalance
        self.server = server
    }

    private var balance: String {
        let amount = walletBalance?.amountShort ?? "--"
        return "\(amount) \(server.symbol)"
    }

    var balanceAttributedString: NSAttributedString {
        return .init(string: balance, attributes: [
            .font: Fonts.regular(size: 20),
            .foregroundColor: Colors.black,
        ])
    }

    var apprecation24HoursAttributedString: NSAttributedString {
        return .init(string: "balance", attributes: [
            .font: Fonts.regular(size: 12),
            .foregroundColor: R.color.dove()!,
        ])
    }

    var accessoryType: UITableViewCell.AccessoryType {
        return .disclosureIndicator
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }
}

