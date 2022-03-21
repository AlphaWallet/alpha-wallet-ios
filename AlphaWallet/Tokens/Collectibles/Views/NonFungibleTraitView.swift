//
//  NonFungibleTraitView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.02.2022.
//

import UIKit

class NonFungibleTraitView: UIView {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    private let countLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        return label
    }()

    let indexPath: IndexPath

    init(edgeInsets: UIEdgeInsets = .init(top: 0, left: 20, bottom: 0, right: 20), indexPath: IndexPath) {
        self.indexPath = indexPath
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let stackView = [
            titleLabel,
            valueLabel,
            countLabel
        ].asStackView(axis: .vertical, spacing: 5)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.anchorsConstraintLessThanOrEqualTo(to: self, edgeInsets: edgeInsets)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: NonFungibleTraitViewModel) {
        titleLabel.attributedText = viewModel.attributedTitle

        valueLabel.attributedText = viewModel.attributedValue
        valueLabel.isHidden = valueLabel.attributedText == nil

        countLabel.attributedText = viewModel.attributedCountValue
        countLabel.isHidden = countLabel.attributedText == nil

        borderColor = viewModel.borderColor
        cornerRadius = viewModel.cornerRadius
        borderWidth = viewModel.borderWidth
    }
}
