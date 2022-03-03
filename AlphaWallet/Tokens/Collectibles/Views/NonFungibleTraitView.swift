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

    private let separatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()

    let indexPath: IndexPath

    init(edgeInsets: UIEdgeInsets = .init(top: 0, left: 20, bottom: 0, right: 20), indexPath: IndexPath) {
        self.indexPath = indexPath
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let subStackView = [titleLabel, valueLabel, countLabel].asStackView(spacing: 5)
        let stackView = [
            .spacer(height: 0, flexible: true),
            subStackView,
            .spacer(height: 0, flexible: true),
            separatorView
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        subStackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)

        NSLayoutConstraint.activate([
            subStackView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -1),
            stackView.anchorsConstraint(to: self, edgeInsets: edgeInsets),
            stackView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            countLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
            separatorView.heightAnchor.constraint(equalToConstant: 1),
            valueLabel.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 100)
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

        separatorView.backgroundColor = viewModel.separatorColor
        separatorView.isHidden = viewModel.isSeparatorHidden
    }
}
