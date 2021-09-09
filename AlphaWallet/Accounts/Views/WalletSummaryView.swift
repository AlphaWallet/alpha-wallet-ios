//
//  WalletSummaryView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.08.2021.
//

import UIKit

class WalletSummaryView: UIView, ReusableTableHeaderViewType {
    private let apprecation24HoursLabel = UILabel()
    private let balanceLabel = UILabel()

    private (set) var viewModel: WalletSummaryViewModel?
    var walletSummarySubscriptionKey: Subscribable<WalletSummary>.SubscribableKey?

    init(edgeInsets: UIEdgeInsets = .init(top: 20, left: 20, bottom: 20, right: 0), spacing: CGFloat = 0) {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = true
        apprecation24HoursLabel.lineBreakMode = .byTruncatingMiddle

        let leftStackView = [
            balanceLabel,
            apprecation24HoursLabel,
        ].asStackView(axis: .vertical, distribution: .fillProportionally, spacing: spacing)

        let stackView = [leftStackView].asStackView(spacing: 0, alignment: .fill)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        apprecation24HoursLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        balanceLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        stackView.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraintLessThanOrEqualTo(to: self, edgeInsets: edgeInsets),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 0),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 0),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: WalletSummaryViewModel) {
        self.viewModel = viewModel

        backgroundColor = viewModel.backgroundColor

        balanceLabel.attributedText = viewModel.balanceAttributedString
        apprecation24HoursLabel.attributedText = viewModel.apprecation24HoursAttributedString
    }
}
