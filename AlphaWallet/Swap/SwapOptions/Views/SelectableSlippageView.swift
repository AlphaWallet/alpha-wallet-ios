//
//  SelectableSlippageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import UIKit

class SelectableSlippageView: UIView {
    private (set) var actionButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false

        return button
    }()

    private var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center

        return label
    }()

    init() {
        super.init(frame: .zero)
        addSubview(actionButton)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            actionButton.anchorsConstraint(to: self),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: SelectableSlippageViewModel) {
        borderColor = viewModel.borderColor
        cornerRadius = viewModel.cornerRadius
        borderWidth = viewModel.borderWidth
        backgroundColor = viewModel.backgroundColor
        titleLabel.attributedText = viewModel.titleAttributedString
    }
}
