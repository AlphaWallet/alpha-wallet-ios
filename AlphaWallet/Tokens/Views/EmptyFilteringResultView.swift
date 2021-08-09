//
//  EmptyFilteringResultView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.08.2021.
//

import Foundation
import UIKit
import StatefulViewController

class EmptyFilteringResultView: UIView {
    private let titleLabel = UILabel()
    private let imageView = UIImageView()
    private let button = Button(size: .large, style: .green)
    private let insets: UIEdgeInsets
    var onRetry: (() -> Void)? = .none
    private let viewModel = StateViewModel()

    init(
        frame: CGRect = .zero,
        title: String = R.string.localizable.empty(),
        image: UIImage? = R.image.no_transactions_mascot(),
        insets: UIEdgeInsets = .zero,
        actionButtonTitle: String = R.string.localizable.addCustomTokenTitle(),
        onRetry: (() -> Void)? = .none
    ) {
        self.insets = insets
        self.onRetry = onRetry
        super.init(frame: frame)

        backgroundColor = .white

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = viewModel.descriptionFont
        titleLabel.textColor = viewModel.descriptionTextColor

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = image

        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(actionButtonTitle, for: .normal)
        button.addTarget(self, action: #selector(retry), for: .touchUpInside)

        let stackView = [
            imageView,
            titleLabel,
        ].asStackView(axis: .vertical, spacing: 30, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        if onRetry != nil {
            stackView.addArrangedSubview(button)
        }

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.bottomAnchor.constraint(equalTo: centerYAnchor, constant: -30),
            button.widthAnchor.constraint(equalToConstant: 230),
        ])
    }

    @objc func retry() {
        onRetry?()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension EmptyFilteringResultView: StatefulPlaceholderView {
    func placeholderViewInsets() -> UIEdgeInsets {
        return insets
    }
}

