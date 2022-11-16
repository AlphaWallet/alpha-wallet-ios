//
//  WalletConnectSessionFieldView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.07.2020.
//

import UIKit
import AlphaWalletFoundation

class WalletConnectSessionFieldView<DetailsView: UIView>: UIStackView {
    fileprivate lazy var titleLabel: UILabel = {
        let titleLabel = UILabel(frame: .zero)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = Fonts.regular(size: 13)
        titleLabel.textAlignment = .left
        titleLabel.textColor = Configuration.Color.Semantic.alternativeText

        return titleLabel
    }()

    fileprivate let detailsView: DetailsView

    init(detailsView: DetailsView) {
        self.detailsView = detailsView
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let textLabelsStackView = [
            titleLabel,
            detailsView,
        ].asStackView(axis: .vertical)

        textLabelsStackView.translatesAutoresizingMaskIntoConstraints = false
        textLabelsStackView.layoutMargins = UIEdgeInsets(top: 0, left: DataEntry.Metric.sideInset, bottom: 0, right: DataEntry.Metric.sideInset)
        textLabelsStackView.isLayoutMarginsRelativeArrangement = true

        addArrangedSubviews([textLabelsStackView])
        axis = .horizontal
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension WalletConnectSessionFieldView {

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
}

extension WalletConnectSessionFieldView where DetailsView: LabeledServerImageView {
    func configure(server: RPCServer) {
        detailsView.configure(viewModel: .init(server: server))
    }
}

extension WalletConnectSessionFieldView where DetailsView: UILabel {
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

extension WalletConnectSessionFieldView {
    static func textLabelView(title: String? = nil, value: String? = nil) -> WalletConnectSessionFieldView<UILabel> {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .left
        label.textColor = Configuration.Color.Semantic.defaultForegroundText
        label.font = Fonts.regular(size: 17)
        label.numberOfLines = 0

        let view: WalletConnectSessionFieldView<UILabel> = .init(detailsView: label)
        view.titleLabel.text = title
        label.text = value

        return view
    }

    static func iconView(title: String? = nil, server: RPCServer) -> WalletConnectSessionFieldView<LabeledServerImageView> {
        let serverImageView = LabeledServerImageView(viewModel: .init(server: server, layout: .horizontal))

        let view: WalletConnectSessionFieldView<LabeledServerImageView> = .init(detailsView: serverImageView)
        view.titleLabel.text = title

        return view
    }
}
