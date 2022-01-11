// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import StatefulViewController

class ErrorView: UIView {
    private let descriptionLabel = UILabel()
    private let imageView = UIImageView()
    private let button = Button(size: .normal, style: .solid)
    private let insets: UIEdgeInsets
    private var onRetry: (() -> Void)? = .none
    private let viewModel = StateViewModel()

    init(
        frame: CGRect = .zero,
        description: String = R.string.localizable.errorViewDescriptionLabelTitle(preferredLanguages: Languages.preferred()),
        image: UIImage? = R.image.error(),
        insets: UIEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
        onRetry: (() -> Void)? = .none
    ) {
        self.onRetry = onRetry
        self.insets = insets
        super.init(frame: frame)

        backgroundColor = .white

        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.text = description
        descriptionLabel.font = viewModel.descriptionFont
        descriptionLabel.textColor = viewModel.descriptionTextColor

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = image

        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(R.string.localizable.retry(preferredLanguages: Languages.preferred()), for: .normal)
        button.addTarget(self, action: #selector(retry), for: .touchUpInside)

        let stackView = [
            imageView,
            descriptionLabel,
            button,
        ].asStackView(axis: .vertical, spacing: viewModel.stackSpacing, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 160),
        ])
    }

    @objc func retry() {
        onRetry?()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ErrorView: StatefulPlaceholderView {
    func placeholderViewInsets() -> UIEdgeInsets {
        return insets
    }
}
