//
//  WalletSummaryHeaderView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.05.2021.
//

import UIKit

class WalletSummaryTableViewCell: UITableViewCell {
    var viewModel: WalletSummaryViewModel? { summaryView.viewModel }

    var walletSummarySubscriptionKey: Subscribable<WalletSummary>.SubscribableKey? {
        get { summaryView.walletSummarySubscriptionKey }
        set { summaryView.walletSummarySubscriptionKey = newValue }
    }

    private let summaryView: WalletSummaryView = .init()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        separatorInset = .zero
        selectionStyle = .none
        contentView.addSubview(summaryView)

        NSLayoutConstraint.activate([
            summaryView.anchorsConstraint(to: contentView, edgeInsets: .zero)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: WalletSummaryViewModel) {
        backgroundColor = viewModel.backgroundColor
        summaryView.configure(viewModel: viewModel)

        accessoryType = .none
    }
}
