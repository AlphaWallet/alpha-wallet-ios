// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

struct TransactionAppearance {

    static func divider(color: UIColor, alpha: Double) -> UIView {
        let view = UIView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return view
    }

    static func item(title: String, subTitle: String, completion:((_ title: String, _ value: String, _ sender: UIView) -> Void)? = .none) -> UIView {
        let titleLabel = UILabel(frame: .zero)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = Fonts.regular(size: 18)
        titleLabel.textAlignment = .left
        titleLabel.textColor = Colors.darkGray

        let subTitleLabel = UILabel(frame: .zero)
        subTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subTitleLabel.text = subTitle
        subTitleLabel.textAlignment = .left
        subTitleLabel.textColor = Colors.black
        subTitleLabel.font = Fonts.light(size: 15)
        subTitleLabel.numberOfLines = 0

        let stackView = [
            titleLabel,
            subTitleLabel,
        ].asStackView(axis: .vertical, spacing: 10)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        stackView.isLayoutMarginsRelativeArrangement = true

        UITapGestureRecognizer(addToView: stackView) {
            completion?(title, subTitle, stackView)
        }

        return stackView
    }
}
