// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import AlphaWalletFoundation
import Combine

extension TransactionFieldView {
    static func textLabelView(title: String? = nil, value: String? = nil, icon: UIImage? = nil) -> TransactionFieldView<UILabel> {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .left
        label.textColor = Configuration.Color.Semantic.defaultForegroundText
        label.font = Fonts.regular(size: 17)
        label.numberOfLines = 0

        let view: TransactionFieldView<UILabel> = .init(detailsView: label)
        view.titleLabel.text = title
        label.text = value
        view.configure(icon: icon)

        return view
    }

    static func iconView(title: String? = nil, server: RPCServer) -> TransactionFieldView<LabeledServerImageView> {
        let serverImageView = LabeledServerImageView(viewModel: .init(server: server, layout: .horizontal))

        let view: TransactionFieldView<LabeledServerImageView> = .init(detailsView: serverImageView)
        view.titleLabel.text = title
        view.iconImageView.image = nil

        return view
    }
}

class TransactionFieldView<DetailsView: UIView>: UIStackView {
    fileprivate lazy var titleLabel: UILabel = {
        let titleLabel = UILabel(frame: .zero)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = Fonts.regular(size: 13)
        titleLabel.textAlignment = .left
        titleLabel.textColor = Configuration.Color.Semantic.alternativeText

        return titleLabel
    }()

    fileprivate let detailsView: DetailsView

    fileprivate lazy var iconImageView: UIImageView = {
        let iconImageView = UIImageView(image: nil)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit

        return iconImageView
    }()

    fileprivate lazy var imageStackView: UIView = {
        let imageStackView = [iconContainerView, .spacerWidth(20)].asStackView(axis: .horizontal)
        imageStackView.isHidden = true

        return imageStackView
    }()

    fileprivate lazy var iconContainerView: UIView = {
        let iconContainerView = UIView()
        iconContainerView.translatesAutoresizingMaskIntoConstraints = false
        iconContainerView.backgroundColor = .clear

        return iconContainerView
    }()

    init(detailsView: DetailsView) {
        self.detailsView = detailsView
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let textLabelsStackView = [
            titleLabel,
            detailsView,
        ].asStackView(axis: .vertical)

        textLabelsStackView.translatesAutoresizingMaskIntoConstraints = false
        textLabelsStackView.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        textLabelsStackView.isLayoutMarginsRelativeArrangement = true

        iconContainerView.addSubview(iconImageView)
        addArrangedSubviews([textLabelsStackView, imageStackView])
        axis = .horizontal

        NSLayoutConstraint.activate([
            iconContainerView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.leadingAnchor.constraint(equalTo: iconContainerView.leadingAnchor),
            iconImageView.trailingAnchor.constraint(equalTo: iconContainerView.trailingAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: detailsView.centerYAnchor)
        ])
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension TransactionFieldView {

    @discardableResult func addTapPublisher() -> AnyPublisher<Void, Never> {
        removeAllGestures()

        return publisher(for: UITapGestureRecognizer())
            .mapToVoid()
            .eraseToAnyPublisher()
    }

    @discardableResult func configure(tapGestureHandler handler: (() -> Void)? = nil) -> Self {
        removeAllGestures()
        if let handler = handler {
            UITapGestureRecognizer(addToView: self, closure: handler)
        }

        return self
    }

    @discardableResult func configure(iconTapGestureHandler handler: (() -> Void)? = nil) -> Self {
        imageStackView.removeAllGestures()
        imageStackView.isUserInteractionEnabled = false

        if let handler = handler {
            imageStackView.isUserInteractionEnabled = true
            UITapGestureRecognizer(addToView: imageStackView, closure: handler)
        }

        return self
    }

    @discardableResult func configure(title: String) -> Self {
        let attributedTitle = NSAttributedString(string: title, attributes: [
            .font: Fonts.regular(size: 13),
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText
        ])

        return configure(attributedTitleText: attributedTitle)
    }

    @discardableResult func configure(attributedTitleText: NSAttributedString) -> Self {
        titleLabel.attributedText = attributedTitleText

        return self
    }

    @discardableResult func configure(icon: UIImage?) -> Self {
        iconImageView.image = icon
        imageStackView.isHidden = icon == nil

        return self
    }
}

extension TransactionFieldView where DetailsView: LabeledServerImageView {
    func configure(server: RPCServer) {
        detailsView.configure(viewModel: .init(server: server))
    }
}

extension TransactionFieldView where DetailsView: UILabel {
    @discardableResult func configure(attributedValueText: NSAttributedString) -> Self {
        detailsView.attributedText = attributedValueText
        return self
    }

    @discardableResult func configure(value: String) -> Self {
        let attributedValue = NSAttributedString(string: value, attributes: [
            .font: Fonts.regular(size: 17),
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText
        ])

        return configure(attributedValueText: attributedValue)
    }
}
