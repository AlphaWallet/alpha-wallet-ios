// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import StatefulViewController

protocol EmptyViewPlacement {
    func resolveContraints(superView: UIView, container: UIView) -> [NSLayoutConstraint]
}

class EmptyView: UIView {
    private let stackView: UIStackView = [].asStackView(axis: .vertical, spacing: 30, alignment: .center)
    private var titleLabel: UILabel?
    private var imageView: UIImageView?
    private var button: Button?
    private var insets: UIEdgeInsets = .zero
    private var buttonSelectionClosure: (() -> Void)? = .none
    private var placementConstraints: [NSLayoutConstraint] = []

    init(placement: EmptyViewPlacement = EmptyViewDefaultPlacement()) {
        super.init(frame: .zero)
        backgroundColor = Colors.appBackground
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        placementConstraints = placement.resolveContraints(superView: self, container: stackView)
        NSLayoutConstraint.activate(placementConstraints)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String?) -> Self {
        let attributedTitle = title.flatMap { value in
            return NSAttributedString.init(string: value, attributes: [
                .foregroundColor: Colors.appText,
                .font: Fonts.regular(size: 16)
            ])
        }
        return configure(attributedTitle: attributedTitle)
    }

    func configure(attributedTitle: NSAttributedString?) -> Self {
        self.titleLabel = attributedTitle.flatMap { attributedTitle -> UILabel in
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.attributedText = attributedTitle

            return label
        }
        return build()
    }

    func configure(image: UIImage?) -> Self {
        self.imageView = image.flatMap { image -> UIImageView in
            let imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.image = image

            return imageView
        }
        return build()
    }

    func configure(buttonTitle title: String?, width: CGFloat = 180, size: ButtonSize = .large, style: ButtonStyle = .green, buttonSelectionClosure: (() -> Void)?) -> Self {
        self.buttonSelectionClosure = buttonSelectionClosure
        self.button = title.flatMap { title -> Button in
            let button = Button(size: size, style: style)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setTitle(title, for: .normal)
            button.addTarget(self, action: #selector(buttonSelected), for: .touchUpInside)
            
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: width)
            ])

            return button
        }
        return build()
    }

    @objc private func buttonSelected(_ sender: UIButton) {
        buttonSelectionClosure?()
    }

    func configure(insets: UIEdgeInsets) -> Self {
        self.insets = insets
        return build()
    }

    func configure(spacing: CGFloat) -> Self {
        stackView.spacing = spacing
        return build()
    }

    func build() -> Self {
        stackView.removeAllArrangedSubviews()
        stackView.addArrangedSubviews([imageView, titleLabel, button].compactMap({ $0 }))
        
        return self
    }
}

extension EmptyView: StatefulPlaceholderView {
    func placeholderViewInsets() -> UIEdgeInsets {
        return insets
    }
}

final class EmptyViewDefaultPlacement: EmptyViewPlacement {
    func resolveContraints(superView: UIView, container: UIView) -> [NSLayoutConstraint] {
        return [
            container.trailingAnchor.constraint(equalTo: superView.trailingAnchor),
            container.leadingAnchor.constraint(equalTo: superView.leadingAnchor),
            container.centerXAnchor.constraint(equalTo: superView.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: superView.centerYAnchor),
        ]
    }
}

final class FilterTokensEmptyViewDefaultPlacement: EmptyViewPlacement {
    func resolveContraints(superView: UIView, container: UIView) -> [NSLayoutConstraint] {
        return [
            container.trailingAnchor.constraint(equalTo: superView.trailingAnchor),
            container.leadingAnchor.constraint(equalTo: superView.leadingAnchor),
            container.centerXAnchor.constraint(equalTo: superView.centerXAnchor),
            container.bottomAnchor.constraint(equalTo: superView.centerYAnchor, constant: -30)
        ]
    }
}

final class FilterTokensHoldersEmptyViewDefaultPlacement: EmptyViewPlacement {
    private let verticalOffset: CGFloat

    init(verticalOffset: CGFloat) {
        self.verticalOffset = verticalOffset
    }

    func resolveContraints(superView: UIView, container: UIView) -> [NSLayoutConstraint] {
        return [
            container.trailingAnchor.constraint(equalTo: superView.trailingAnchor),
            container.leadingAnchor.constraint(equalTo: superView.leadingAnchor),
            container.centerXAnchor.constraint(equalTo: superView.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: superView.centerYAnchor, constant: verticalOffset)
        ]
    }
}

extension EmptyView {
    static func tokensEmptyView(completion: @escaping () -> Void) -> EmptyView {
        EmptyView()
            .configure(image: R.image.no_transactions_mascot())
            .configure(title: R.string.localizable.emptyViewNoTokensLabelTitle())
            .configure(buttonTitle: R.string.localizable.refresh(), width: 240, buttonSelectionClosure: completion)
            .configure(spacing: 30)
            .configure(insets: .init(top: Style.SearchBar.height, left: 0, bottom: 0, right: 0))
    }

    static func walletSessionEmptyView(completion: @escaping () -> Void) -> EmptyView {
        EmptyView()
            .configure(spacing: 24)
            .configure(insets: .zero)
            .configure(image: R.image.iconsIllustrationsEmptyWalletConnect())
            .configure(title: R.string.localizable.walletConnectSessionsEmpty())
            .configure(buttonTitle: R.string.localizable.walletConnectSessionsScanQrCode(), width: 240, buttonSelectionClosure: completion)
    }

    static func transactionsEmptyView() -> EmptyView {
        EmptyView()
            .configure(image: R.image.no_transactions_mascot())
            .configure(title: R.string.localizable.emptyViewNoTokensLabelTitle())
            .configure(spacing: 30)
            .configure(insets: .zero)
    }

    static func activitiesEmptyView() -> EmptyView {
        EmptyView()
            .configure(image: R.image.activities_empty_list())
            .configure(title: R.string.localizable.activityEmpty())
            .configure(spacing: 30)
            .configure(insets: .zero)
    }

    static func priceAlertsEmpryView() -> EmptyView {
        EmptyView()
            .configure(image: R.image.iconsIllustrationsAlert2())
            .configure(title: R.string.localizable.activityEmpty())
            .configure(spacing: 0)
            .configure(insets: .zero)
    }

    static func filterTokensEmptyView(completion: @escaping () -> Void) -> EmptyView {
        EmptyView(placement: FilterTokensEmptyViewDefaultPlacement())
            .configure(image: R.image.iconsIllustrationsSearchResults())
            .configure(title: R.string.localizable.seachTokenNoresultsTitle())
            .configure(buttonTitle: R.string.localizable.addCustomTokenTitle(), width: 240, buttonSelectionClosure: completion)
            .configure(spacing: 30)
            .configure(insets: .zero)
    }

    static func filterTokenHoldersEmptyView() -> EmptyView {
        EmptyView(placement: FilterTokensHoldersEmptyViewDefaultPlacement(verticalOffset: -20))
            .configure(image: R.image.iconsIllustrationsSearchResults())
            .configure(title: R.string.localizable.seachTokenNoresultsTitle())
            .configure(spacing: 30)
            .configure(insets: .init(top: Style.SearchBar.height, left: 0, bottom: 0, right: 0))
    }
}
