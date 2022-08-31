// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

class AccountViewTableSectionHeader: UIView {
    private let label = UILabel()
    private var heightConstraint: NSLayoutConstraint?
    private var constraintsWhenVisible: [NSLayoutConstraint] = []
    private let topSeparatorView = UIView.tableHeaderFooterViewSeparatorView()
    private let bottomSeparatorView = UIView.tableHeaderFooterViewSeparatorView()

    override init(frame: CGRect) {
        super.init(frame: CGRect())

        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(topSeparatorView)
        addSubview(bottomSeparatorView)
        addSubview(label)

        let topConstraint = label.topAnchor.constraint(equalTo: topSeparatorView.bottomAnchor, constant: 12)
        let bottomConstraint = label.bottomAnchor.constraint(equalTo: bottomSeparatorView.topAnchor, constant: -12)
        let constraintsWhenVisible = [
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            topSeparatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            topSeparatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            topSeparatorView.topAnchor.constraint(equalTo: topAnchor),

            bottomSeparatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomSeparatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomSeparatorView.bottomAnchor.constraint(equalTo: bottomAnchor),

            topConstraint,
            bottomConstraint
        ]

        NSLayoutConstraint.activate(constraintsWhenVisible)

        //UIKit doesn't like headers with a height of 0
        heightConstraint = heightAnchor.constraint(equalToConstant: 1)
        self.constraintsWhenVisible = constraintsWhenVisible
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(type: AccountsViewModel.Section, shouldHide: Bool) {
        backgroundColor = Configuration.Color.Semantic.tableViewHeaderBackground
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = 25
        paragraphStyle.maximumLineHeight = 25
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Style.Wallet.Header.font as Any,
            .paragraphStyle: paragraphStyle,
            .backgroundColor: Configuration.Color.Semantic.defaultViewBackground,
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText]
        let attrString = NSAttributedString(string: type.title, attributes: attributes)
        label.attributedText = attrString
        label.isHidden = shouldHide

        heightConstraint?.isActive = shouldHide
        if shouldHide {
            NSLayoutConstraint.deactivate(constraintsWhenVisible)
        } else {
            NSLayoutConstraint.activate(constraintsWhenVisible)
        }
    }
}
