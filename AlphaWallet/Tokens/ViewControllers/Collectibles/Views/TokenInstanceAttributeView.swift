//
//  TokenInstanceAttributeView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit

class TokenInstanceAttributeView: UIView {

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
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let separatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()

    init(edgeInsets: UIEdgeInsets = .init(top: 5, left: 20, bottom: 5, right: 20)) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            [titleLabel, valueLabel].asStackView(spacing: 5),
            separatorView
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self, edgeInsets: edgeInsets),
            stackView.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            separatorView.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: TokenInstanceAttributeViewModel) {
        titleLabel.attributedText = viewModel.attributedTitle

        valueLabel.attributedText = viewModel.attributedValue
        valueLabel.isHidden = valueLabel.attributedText == nil

        separatorView.backgroundColor = viewModel.separatorColor
        separatorView.isHidden = viewModel.isSeparatorHidden
    }
}

struct TokenInstanceAttributeViewModel {
    private let title: String?
    var attributedValue: NSAttributedString?
    var separatorColor: UIColor = R.color.mercury()!
    var isSeparatorHidden: Bool = false

    init(title: String?, attributedValue: NSAttributedString?, isSeparatorHidden: Bool = false) {
        self.title = title
        self.attributedValue = attributedValue
        self.isSeparatorHidden = isSeparatorHidden
    }

    var attributedTitle: NSAttributedString? {
        title.flatMap { Self.defaultTitleAttributedString($0) }
    }

    static func defaultTitleAttributedString(_ value: String, alignment: NSTextAlignment = .left) -> NSAttributedString {
        attributedString(value, alignment: alignment, font: Fonts.regular(size: 15), foregroundColor: R.color.dove()!)
    }

    static func defaultValueAttributedString(_ value: String, alignment: NSTextAlignment = .right) -> NSAttributedString {
        attributedString(value, alignment: alignment, font: Fonts.regular(size: 17), foregroundColor: Colors.black)
    }

    static func boldValueAttributedString(_ value: String, alignment: NSTextAlignment = .right) -> NSAttributedString {
        attributedString(value, alignment: alignment, font: Screen.TokenCard.Font.valueChangeValue, foregroundColor: Colors.black)
    }

    private static func attributedString(_ value: String, alignment: NSTextAlignment, font: UIFont, foregroundColor: UIColor) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment

        return .init(string: value, attributes: [
            .font: font,
            .foregroundColor: foregroundColor,
            .paragraphStyle: paragraphStyle
        ])
    }
}
