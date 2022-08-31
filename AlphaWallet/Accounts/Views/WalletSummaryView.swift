//
//  WalletSummaryView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.08.2021.
//

import UIKit
import Combine

class WalletSummaryView: UIView, ReusableTableHeaderViewType {
    private let apprecation24HoursLabel = UILabel()
    private let balanceLabel = UILabel()

    init(edgeInsets: UIEdgeInsets = .init(top: 20, left: 20, bottom: 20, right: 0), spacing: CGFloat = 0) {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = true
        apprecation24HoursLabel.lineBreakMode = .byTruncatingMiddle

        let leftStackView = [
            balanceLabel,
            apprecation24HoursLabel,
        ].asStackView(axis: .vertical, spacing: spacing)

        let stackView = [leftStackView].asStackView(spacing: 0, alignment: .fill)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        apprecation24HoursLabel.setContentHuggingPriority(.required, for: .horizontal)
        balanceLabel.setContentHuggingPriority(.required, for: .horizontal)

        stackView.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(stackView)

        NSLayoutConstraint.activate([
            balanceLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).set(priority: .defaultHigh),
            apprecation24HoursLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).set(priority: .defaultHigh),
            stackView.anchorsConstraintLessThanOrEqualTo(to: self, edgeInsets: edgeInsets),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 0),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 0),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: WalletSummaryViewModel) {
        backgroundColor = viewModel.backgroundColor

        balanceLabel.attributedText = viewModel.balanceAttributedString
        apprecation24HoursLabel.attributedText = viewModel.apprecation24HoursAttributedString
    }
}
