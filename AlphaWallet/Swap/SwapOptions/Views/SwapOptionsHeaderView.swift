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

    lazy var trailingStackView: UIStackView = {
        let view = [].asStackView(axis: .horizontal)
        view.isHidden = true
        return view
    }()

    init(viewModel: SwapOptionsHeaderViewModel) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let stackView = [titleLabel, slippageInfoButton, .spacerWidth(flexible: true), trailingStackView].asStackView(axis: .horizontal, spacing: 5, alignment: .leading)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self),
            trailingStackView.heightAnchor.constraint(equalTo: stackView.heightAnchor),
            trailingStackView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            slippageInfoButton.centerYAnchor.constraint(equalTo: centerYAnchor),
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

extension SwapOptionsHeaderView {
    func enableTapAction(title: String) -> UIButton {

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right

        let attributedText = NSAttributedString(string: title, attributes: [
            .font: Fonts.bold(size: 17) as Any,
            .foregroundColor: Colors.appTint,
            .paragraphStyle: paragraph
        ])

        let button = UIButton(type: .system)
        button.setAttributedTitle(attributedText, for: .normal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.translatesAutoresizingMaskIntoConstraints = false

        trailingStackView.addArrangedSubview(button)
        trailingStackView.isHidden = false

        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),
            button.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
        ])

        return button
    }

}
