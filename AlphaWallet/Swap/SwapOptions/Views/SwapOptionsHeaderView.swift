//
//  SwapOptionsHeaderView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import UIKit

class SwapOptionsHeaderView: UIView {

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        return label
    }()

    private lazy var slippageInfoButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 16).isActive = true
        button.widthAnchor.constraint(equalToConstant: 16).isActive = true
        button.setImage(R.image.iconsSystemQuestionMark(), for: .normal)
        //NOTE: mark it as hidden for now
        button.alpha = 0

        return button
    }()

    init(viewModel: SwapOptionsHeaderViewModel) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let stackView = [titleLabel, slippageInfoButton, .spacerWidth(flexible: true)].asStackView(axis: .horizontal, spacing: 5, alignment: .leading)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self),
            titleLabel.centerYAnchor.constraint(equalTo: slippageInfoButton.centerYAnchor)
        ])

        configure(viewModel: viewModel)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: SwapOptionsHeaderViewModel) {
        titleLabel.attributedText = viewModel.attributedTitle
    }

}
