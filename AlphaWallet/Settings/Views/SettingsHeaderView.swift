// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class SettingsHeaderView: UIView {
    private let titleLabel = UILabel()

    var title: String? {
        get {
            return titleLabel.text
        }
        set {
            titleLabel.text = newValue
            layoutIfNeeded()
        }
    }

    init() {
        //TODO remove duplicate of TransactionsViewController.headerView(for:)
        super.init(frame: .zero)

        titleLabel.textColor = Colors.appWhite
        titleLabel.font = Fonts.regular(size: 16)!
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
