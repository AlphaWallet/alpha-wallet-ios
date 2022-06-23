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
    private var cancelable = Set<AnyCancellable>()

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
        cancelable.cancellAll()

        viewModel.balanceAttributedString
            .sink { [weak balanceLabel] value in
                balanceLabel?.attributedText = value
            }.store(in: &cancelable)

        viewModel.apprecation24HoursAttributedString
            .sink { [weak apprecation24HoursLabel] value in
                apprecation24HoursLabel?.attributedText = value
            }.store(in: &cancelable)
    }
}

extension Set where Element: AnyCancellable {
    mutating func cancellAll() {
        for each in self {
            each.cancel()
        }

        removeAll()
    }
}
